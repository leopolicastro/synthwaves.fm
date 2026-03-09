require "rails_helper"

RSpec.describe IPTVChannelSyncService do
  let(:playlist_content) do
    <<~M3U
      #EXTM3U
      #EXTINF:-1 tvg-id="CNN.us" tvg-logo="https://example.com/cnn.png" group-title="News" tvg-country="US" tvg-language="English",CNN International
      https://stream.example.com/cnn.m3u8
      #EXTINF:-1 tvg-id="BBC.uk" tvg-logo="https://example.com/bbc.png" group-title="News" tvg-country="UK" tvg-language="English",BBC World
      https://stream.example.com/bbc.m3u8
      #EXTINF:-1 tvg-id="MTV.us" tvg-logo="https://example.com/mtv.png" group-title="Music" tvg-country="US" tvg-language="English",MTV
      https://stream.example.com/mtv.m3u8
    M3U
  end

  before do
    stub_request(:get, IPTVChannelSyncService::PLAYLIST_URL)
      .to_return(status: 200, body: playlist_content)
  end

  describe ".call" do
    it "imports channels from the playlist" do
      result = described_class.call

      expect(result[:synced]).to eq(3)
      expect(IPTVChannel.count).to eq(3)
      expect(IPTVCategory.count).to eq(2)
    end

    it "creates categories from group titles" do
      described_class.call

      expect(IPTVCategory.pluck(:name)).to contain_exactly("News", "Music")
    end

    it "sets channel attributes correctly" do
      described_class.call

      channel = IPTVChannel.find_by(tvg_id: "CNN.us")
      expect(channel.name).to eq("CNN International")
      expect(channel.stream_url).to eq("https://stream.example.com/cnn.m3u8")
      expect(channel.logo_url).to eq("https://example.com/cnn.png")
      expect(channel.country).to eq("US")
      expect(channel.language).to eq("English")
      expect(channel.iptv_category.name).to eq("News")
      expect(channel).to be_active
    end

    it "updates existing channels on re-sync" do
      described_class.call

      updated_content = playlist_content.gsub("CNN International", "CNN Updated")
      stub_request(:get, IPTVChannelSyncService::PLAYLIST_URL)
        .to_return(status: 200, body: updated_content)

      described_class.call

      channel = IPTVChannel.find_by(tvg_id: "CNN.us")
      expect(channel.name).to eq("CNN Updated")
      expect(IPTVChannel.count).to eq(3)
    end

    it "deactivates channels removed from upstream" do
      described_class.call

      # Re-sync with only CNN
      reduced_content = <<~M3U
        #EXTM3U
        #EXTINF:-1 tvg-id="CNN.us" group-title="News",CNN International
        https://stream.example.com/cnn.m3u8
      M3U

      stub_request(:get, IPTVChannelSyncService::PLAYLIST_URL)
        .to_return(status: 200, body: reduced_content)

      described_class.call

      expect(IPTVChannel.find_by(tvg_id: "CNN.us")).to be_active
      expect(IPTVChannel.find_by(tvg_id: "BBC.uk")).not_to be_active
      expect(IPTVChannel.find_by(tvg_id: "MTV.us")).not_to be_active
    end

    it "deduplicates entries by tvg_id" do
      duplicate_content = <<~M3U
        #EXTM3U
        #EXTINF:-1 tvg-id="CNN.us",CNN First
        https://stream1.example.com/cnn.m3u8
        #EXTINF:-1 tvg-id="CNN.us",CNN Second
        https://stream2.example.com/cnn.m3u8
      M3U

      stub_request(:get, IPTVChannelSyncService::PLAYLIST_URL)
        .to_return(status: 200, body: duplicate_content)

      result = described_class.call

      expect(result[:synced]).to eq(1)
      expect(IPTVChannel.count).to eq(1)
    end

    it "creates entries without tvg_id individually" do
      content_without_id = <<~M3U
        #EXTM3U
        #EXTINF:-1 group-title="News",No ID Channel
        https://stream.example.com/noid.m3u8
      M3U

      stub_request(:get, IPTVChannelSyncService::PLAYLIST_URL)
        .to_return(status: 200, body: content_without_id)

      result = described_class.call

      expect(result[:synced]).to eq(1)
      expect(IPTVChannel.count).to eq(1)
      expect(IPTVChannel.first.tvg_id).to be_nil
    end

    it "updates category counter caches" do
      described_class.call

      news = IPTVCategory.find_by(name: "News")
      expect(news.channels_count).to eq(2)

      music = IPTVCategory.find_by(name: "Music")
      expect(music.channels_count).to eq(1)
    end
  end

  describe ".import" do
    it "imports from a custom URL without deactivating existing channels" do
      # Create an existing channel that should NOT be deactivated
      existing = create(:iptv_channel, tvg_id: "existing.ch", active: true)

      custom_playlist = <<~M3U
        #EXTM3U
        #EXTINF:-1 tvg-id="custom.ch" group-title="Live",Custom Channel
        https://stream.example.com/custom.m3u8
      M3U

      stub_request(:get, "https://example.com/custom.m3u")
        .to_return(status: 200, body: custom_playlist)

      result = described_class.import("https://example.com/custom.m3u")

      expect(result[:synced]).to eq(1)
      expect(existing.reload).to be_active
    end

    it "imports entries without tvg_id" do
      playlist = <<~M3U
        #EXTM3U
        #EXTINF:-1 group-title="Live",No ID Channel
        https://stream.example.com/noid.m3u8
      M3U

      stub_request(:get, "https://example.com/playlist.m3u")
        .to_return(status: 200, body: playlist)

      result = described_class.import("https://example.com/playlist.m3u")

      expect(result[:synced]).to eq(1)
      expect(IPTVChannel.find_by(name: "No ID Channel")).to be_present
    end
  end
end
