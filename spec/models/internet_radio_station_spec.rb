require "rails_helper"

RSpec.describe InternetRadioStation, type: :model do
  describe "associations" do
    it { should belong_to(:internet_radio_category).optional }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:internet_radio_station) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:stream_url) }
    it { should validate_uniqueness_of(:uuid) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active stations" do
        active = create(:internet_radio_station, active: true)
        create(:internet_radio_station, :inactive)

        expect(described_class.active).to eq([active])
      end
    end

    describe ".by_country" do
      it "filters by country code" do
        us_station = create(:internet_radio_station, country_code: "US")
        create(:internet_radio_station, country_code: "DE")

        expect(described_class.by_country("US")).to eq([us_station])
      end

      it "returns all when code is blank" do
        create(:internet_radio_station)
        expect(described_class.by_country(nil).count).to eq(1)
      end
    end

    describe ".by_tag" do
      it "filters by tag" do
        rock = create(:internet_radio_station, tags: "rock,classic rock")
        create(:internet_radio_station, tags: "jazz,smooth")

        expect(described_class.by_tag("rock")).to eq([rock])
      end
    end

    describe ".search" do
      it "searches by name" do
        station = create(:internet_radio_station, name: "Classic Rock FM")
        create(:internet_radio_station, name: "Jazz Radio")

        expect(described_class.search("Classic")).to eq([station])
      end
    end

    describe ".popular" do
      it "orders by votes descending" do
        low = create(:internet_radio_station, votes: 10)
        high = create(:internet_radio_station, votes: 1000)

        expect(described_class.popular).to eq([high, low])
      end
    end
  end

  describe "#display_favicon_url" do
    it "returns favicon_url when present" do
      station = build(:internet_radio_station, favicon_url: "https://example.com/logo.png", homepage_url: "https://example.com")
      expect(station.display_favicon_url).to eq("https://example.com/logo.png")
    end

    it "returns Google favicon URL when favicon_url is blank but homepage_url is present" do
      station = build(:internet_radio_station, favicon_url: nil, homepage_url: "https://big1059.iheart.com/")
      expect(station.display_favicon_url).to eq("https://www.google.com/s2/favicons?domain=big1059.iheart.com&sz=128")
    end

    it "returns nil when both are blank" do
      station = build(:internet_radio_station, favicon_url: nil, homepage_url: nil)
      expect(station.display_favicon_url).to be_nil
    end
  end

  describe "#needs_proxy?" do
    it "returns true for HTTP streams" do
      station = build(:internet_radio_station, stream_url: "http://stream.example.com/radio.mp3")
      expect(station.needs_proxy?).to be true
    end

    it "returns false for HTTPS streams" do
      station = build(:internet_radio_station, stream_url: "https://stream.example.com/radio.mp3")
      expect(station.needs_proxy?).to be false
    end

    it "returns false when stream_url is blank" do
      station = build(:internet_radio_station)
      station.stream_url = nil
      expect(station.needs_proxy?).to be false
    end
  end
end
