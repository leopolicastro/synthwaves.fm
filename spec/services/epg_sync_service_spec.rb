require "rails_helper"

RSpec.describe EPGSyncService do
  let(:epg_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <tv>
        <programme start="#{format_xmltv(1.hour.ago)}" stop="#{format_xmltv(1.hour.from_now)}" channel="espn.us">
          <title>NHL Hockey</title>
          <sub-title>Red Wings @ Devils</sub-title>
          <desc>Regular season game.</desc>
        </programme>
        <programme start="#{format_xmltv(1.hour.from_now)}" stop="#{format_xmltv(3.hours.from_now)}" channel="espn.us">
          <title>SportsCenter</title>
        </programme>
        <programme start="#{format_xmltv(1.hour.ago)}" stop="#{format_xmltv(1.hour.from_now)}" channel="unknown.channel">
          <title>Unknown Show</title>
        </programme>
      </tv>
    XML
  end

  before do
    create(:iptv_channel, tvg_id: "espn.us")

    stub_request(:get, EPGSyncService::EPG_URL)
      .to_return(status: 200, body: epg_xml)
  end

  describe ".call" do
    it "creates EPG programmes for known channels" do
      result = described_class.call

      expect(result[:synced]).to eq(2)
      expect(result[:channels]).to eq(1)
      expect(EPGProgramme.count).to eq(2)
    end

    it "filters out programmes for unknown channels" do
      described_class.call

      expect(EPGProgramme.where(channel_id: "unknown.channel").count).to eq(0)
    end

    it "stores programme details correctly" do
      described_class.call

      programme = EPGProgramme.find_by(title: "NHL Hockey")
      expect(programme.channel_id).to eq("espn.us")
      expect(programme.subtitle).to eq("Red Wings @ Devils")
      expect(programme.description).to eq("Regular season game.")
    end

    it "cleans up expired programmes" do
      create(:epg_programme, channel_id: "espn.us", ends_at: 3.hours.ago)

      described_class.call

      expect(EPGProgramme.where("ends_at < ?", 1.hour.ago).count).to eq(0)
    end

    it "replaces current/future programmes on re-sync" do
      create(:epg_programme, channel_id: "espn.us", title: "Old Show",
             starts_at: 30.minutes.ago, ends_at: 30.minutes.from_now)

      described_class.call

      expect(EPGProgramme.where(title: "Old Show").count).to eq(0)
      expect(EPGProgramme.where(channel_id: "espn.us").count).to eq(2)
    end

    it "handles channels with no tvg_id" do
      create(:iptv_channel, tvg_id: nil)

      expect { described_class.call }.not_to raise_error
    end
  end

  private

  def format_xmltv(time)
    time.utc.strftime("%Y%m%d%H%M%S +0000")
  end
end
