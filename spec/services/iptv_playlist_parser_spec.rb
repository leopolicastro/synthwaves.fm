require "rails_helper"

RSpec.describe IPTVPlaylistParser do
  describe ".parse" do
    it "parses a standard IPTV M3U playlist" do
      content = <<~M3U
        #EXTM3U
        #EXTINF:-1 tvg-id="CNN.us" tvg-logo="https://example.com/cnn.png" group-title="News" tvg-country="US" tvg-language="English",CNN International
        https://stream.example.com/cnn.m3u8
        #EXTINF:-1 tvg-id="BBC.uk" tvg-logo="https://example.com/bbc.png" group-title="News" tvg-country="UK" tvg-language="English",BBC World
        https://stream.example.com/bbc.m3u8
      M3U

      entries = described_class.parse(content)

      expect(entries.size).to eq(2)

      cnn = entries.first
      expect(cnn.tvg_id).to eq("CNN.us")
      expect(cnn.name).to eq("CNN International")
      expect(cnn.logo_url).to eq("https://example.com/cnn.png")
      expect(cnn.group_title).to eq("News")
      expect(cnn.country).to eq("US")
      expect(cnn.language).to eq("English")
      expect(cnn.stream_url).to eq("https://stream.example.com/cnn.m3u8")
    end

    it "handles entries without tvg-id" do
      content = <<~M3U
        #EXTM3U
        #EXTINF:-1 group-title="Music",Lo-Fi Radio
        https://stream.example.com/lofi.m3u8
      M3U

      entries = described_class.parse(content)

      expect(entries.size).to eq(1)
      expect(entries.first.tvg_id).to be_nil
      expect(entries.first.name).to eq("Lo-Fi Radio")
    end

    it "handles entries with empty attribute values" do
      content = <<~M3U
        #EXTM3U
        #EXTINF:-1 tvg-id="test.ch" tvg-logo="" group-title="",Test Channel
        https://stream.example.com/test.m3u8
      M3U

      entries = described_class.parse(content)

      expect(entries.first.logo_url).to be_nil
      expect(entries.first.group_title).to be_nil
    end

    it "handles entries with no metadata line" do
      content = <<~M3U
        #EXTM3U
        https://stream.example.com/direct.m3u8
      M3U

      entries = described_class.parse(content)

      expect(entries.size).to eq(1)
      expect(entries.first.name).to eq("Unknown")
      expect(entries.first.stream_url).to eq("https://stream.example.com/direct.m3u8")
    end

    it "returns empty array for empty content" do
      expect(described_class.parse("")).to eq([])
    end

    it "skips comment lines that are not EXTINF" do
      content = <<~M3U
        #EXTM3U
        # This is a comment
        #EXTINF:-1 tvg-id="test.ch",Test
        https://stream.example.com/test.m3u8
      M3U

      entries = described_class.parse(content)
      expect(entries.size).to eq(1)
    end
  end
end
