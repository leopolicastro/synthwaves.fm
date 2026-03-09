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

    it "nullifies recording references before deleting expired programmes" do
      expired = create(:epg_programme, channel_id: "espn.us", ends_at: 3.hours.ago)
      recording = create(:recording, epg_programme: expired)

      described_class.call

      expect(recording.reload.epg_programme_id).to be_nil
    end

    it "upserts programmes instead of deleting on re-sync" do
      # Use truncated time to match XMLTV parser precision (no subseconds)
      starts = 1.hour.ago.change(usec: 0)
      existing = create(:epg_programme, channel_id: "espn.us", title: "NHL Hockey",
                       starts_at: starts, ends_at: 1.hour.from_now)

      xml_with_match = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="#{format_xmltv(starts)}" stop="#{format_xmltv(1.hour.from_now)}" channel="espn.us">
            <title>NHL Hockey</title>
            <sub-title>Updated Subtitle</sub-title>
          </programme>
        </tv>
      XML
      stub_request(:get, EPGSyncService::EPG_URL)
        .to_return(status: 200, body: xml_with_match)

      described_class.call

      expect(existing.reload.subtitle).to eq("Updated Subtitle")
    end

    it "preserves programmes from earlier syncs outside current feed window" do
      tomorrow = create(:epg_programme, channel_id: "espn.us", title: "Tomorrow Show",
                       starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)

      described_class.call

      expect(EPGProgramme.find_by(id: tomorrow.id)).to be_present
    end

    it "handles channels with no tvg_id" do
      create(:iptv_channel, tvg_id: nil)

      expect { described_class.call }.not_to raise_error
    end
  end

  describe "per-channel EPG URLs" do
    let(:custom_epg_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="#{format_xmltv(2.hours.from_now)}" stop="#{format_xmltv(4.hours.from_now)}" channel="bbc1.uk">
            <title>BBC News</title>
          </programme>
        </tv>
      XML
    end

    let(:custom_epg_url) { "https://epg.example.com/uk.xml" }

    before do
      create(:iptv_channel, tvg_id: "bbc1.uk", epg_url: custom_epg_url)

      stub_request(:get, custom_epg_url)
        .to_return(status: 200, body: custom_epg_xml)
    end

    it "fetches from per-channel EPG URLs" do
      described_class.call

      expect(EPGProgramme.find_by(channel_id: "bbc1.uk", title: "BBC News")).to be_present
    end

    it "skips channels with custom EPG URLs from the global feed" do
      global_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="#{format_xmltv(1.hour.ago)}" stop="#{format_xmltv(1.hour.from_now)}" channel="bbc1.uk">
            <title>Global BBC Show</title>
          </programme>
        </tv>
      XML
      stub_request(:get, EPGSyncService::EPG_URL)
        .to_return(status: 200, body: global_xml)

      described_class.call

      expect(EPGProgramme.find_by(title: "Global BBC Show")).to be_nil
      expect(EPGProgramme.find_by(title: "BBC News")).to be_present
    end

    it "groups channels sharing the same EPG URL into one fetch" do
      create(:iptv_channel, tvg_id: "bbc2.uk", epg_url: custom_epg_url)

      described_class.call

      expect(WebMock).to have_requested(:get, custom_epg_url).once
    end

    it "continues syncing if a custom EPG URL fails" do
      stub_request(:get, custom_epg_url).to_timeout

      result = described_class.call

      expect(result[:synced]).to eq(2)
      expect(EPGProgramme.where(channel_id: "espn.us").count).to eq(2)
    end

    it "remaps feed channel IDs to tvg_id when they differ for a single channel" do
      channel = create(:iptv_channel, tvg_id: "usa-network.us", epg_url: "https://epg.example.com/usa.xml")

      foreign_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="#{format_xmltv(1.hour.from_now)}" stop="#{format_xmltv(2.hours.from_now)}" channel="465006">
            <title>Law &amp; Order: SVU</title>
          </programme>
        </tv>
      XML
      stub_request(:get, "https://epg.example.com/usa.xml")
        .to_return(status: 200, body: foreign_xml)

      described_class.call

      programme = EPGProgramme.find_by(title: "Law & Order: SVU")
      expect(programme).to be_present
      expect(programme.channel_id).to eq("usa-network.us")
    end
  end

  private

  def format_xmltv(time)
    time.utc.strftime("%Y%m%d%H%M%S +0000")
  end
end
