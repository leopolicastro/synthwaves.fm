require "rails_helper"

RSpec.describe IPTVChannelsHelper, type: :helper do
  describe "#retro_tv_channels_json" do
    it "returns valid JSON with channel data" do
      channel = create(:iptv_channel, name: "CNN", stream_url: "https://stream.example.com/cnn.m3u8", logo_url: "https://example.com/cnn.png")
      result = JSON.parse(helper.retro_tv_channels_json([channel], {}))

      expect(result.length).to eq(1)
      expect(result.first).to include(
        "name" => "CNN",
        "streamUrl" => "https://stream.example.com/cnn.m3u8",
        "logoUrl" => "https://example.com/cnn.png",
        "programmes" => []
      )
    end

    it "includes programme data with timestamps" do
      channel = create(:iptv_channel, tvg_id: "cnn.us")
      programme = create(:epg_programme, channel_id: "cnn.us", title: "Breaking News", subtitle: "Live Coverage")

      programmes_by_channel = {"cnn.us" => [programme]}
      result = JSON.parse(helper.retro_tv_channels_json([channel], programmes_by_channel))

      prog = result.first["programmes"].first
      expect(prog["title"]).to eq("Breaking News")
      expect(prog["subtitle"]).to eq("Live Coverage")
      expect(prog["startsAt"]).to eq(programme.starts_at.to_i)
      expect(prog["endsAt"]).to eq(programme.ends_at.to_i)
    end

    it "handles channels with no EPG data" do
      channel = create(:iptv_channel, tvg_id: "unknown.channel")
      result = JSON.parse(helper.retro_tv_channels_json([channel], {}))

      expect(result.first["programmes"]).to eq([])
    end
  end
end
