require "rails_helper"

RSpec.describe XMLTVParser do
  describe ".parse" do
    it "parses valid XMLTV content" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308200000 +0000" stop="20260308210000 +0000" channel="espn.us">
            <title>NHL Hockey</title>
            <sub-title>Red Wings @ Devils</sub-title>
            <desc>Regular season hockey game.</desc>
          </programme>
        </tv>
      XML

      entries = described_class.parse(xml)

      expect(entries.size).to eq(1)
      entry = entries.first
      expect(entry.channel_id).to eq("espn.us")
      expect(entry.title).to eq("NHL Hockey")
      expect(entry.subtitle).to eq("Red Wings @ Devils")
      expect(entry.description).to eq("Regular season hockey game.")
      expect(entry.starts_at).to eq(Time.utc(2026, 3, 8, 20, 0, 0))
      expect(entry.ends_at).to eq(Time.utc(2026, 3, 8, 21, 0, 0))
    end

    it "parses multiple programmes" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308200000 +0000" stop="20260308210000 +0000" channel="espn.us">
            <title>NHL Hockey</title>
          </programme>
          <programme start="20260308210000 +0000" stop="20260308230000 +0000" channel="espn.us">
            <title>SportsCenter</title>
          </programme>
        </tv>
      XML

      entries = described_class.parse(xml)
      expect(entries.size).to eq(2)
      expect(entries.map(&:title)).to eq(["NHL Hockey", "SportsCenter"])
    end

    it "handles missing optional fields" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308200000 +0000" stop="20260308210000 +0000" channel="espn.us">
            <title>NHL Hockey</title>
          </programme>
        </tv>
      XML

      entry = described_class.parse(xml).first
      expect(entry.subtitle).to be_nil
      expect(entry.description).to be_nil
    end

    it "skips entries with missing title" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308200000 +0000" stop="20260308210000 +0000" channel="espn.us">
          </programme>
        </tv>
      XML

      expect(described_class.parse(xml)).to be_empty
    end

    it "skips entries with missing channel" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308200000 +0000" stop="20260308210000 +0000">
            <title>NHL Hockey</title>
          </programme>
        </tv>
      XML

      expect(described_class.parse(xml)).to be_empty
    end

    it "skips entries with invalid timestamps" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="not-a-date" stop="20260308210000 +0000" channel="espn.us">
            <title>NHL Hockey</title>
          </programme>
        </tv>
      XML

      expect(described_class.parse(xml)).to be_empty
    end

    it "skips entries with missing timestamps" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme channel="espn.us">
            <title>NHL Hockey</title>
          </programme>
        </tv>
      XML

      expect(described_class.parse(xml)).to be_empty
    end

    it "handles timezone offsets" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308150000 -0500" stop="20260308160000 -0500" channel="espn.us">
            <title>NHL Hockey</title>
          </programme>
        </tv>
      XML

      entry = described_class.parse(xml).first
      expect(entry.starts_at).to eq(Time.utc(2026, 3, 8, 20, 0, 0))
    end

    it "handles empty XML" do
      expect(described_class.parse("")).to be_empty
    end

    it "strips whitespace from text fields" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme start="20260308200000 +0000" stop="20260308210000 +0000" channel="espn.us">
            <title>  NHL Hockey  </title>
            <sub-title>  Red Wings @ Devils  </sub-title>
            <desc>  A game.  </desc>
          </programme>
        </tv>
      XML

      entry = described_class.parse(xml).first
      expect(entry.title).to eq("NHL Hockey")
      expect(entry.subtitle).to eq("Red Wings @ Devils")
      expect(entry.description).to eq("A game.")
    end
  end
end
