require "rails_helper"

RSpec.describe RadioBrowserSyncService do
  let(:api_response) do
    [
      {
        "stationuuid" => "abc-123",
        "name" => "Test Radio",
        "url_resolved" => "https://stream.example.com/radio.mp3",
        "url" => "https://stream.example.com/radio.mp3",
        "homepage" => "https://testradio.com",
        "favicon" => "https://testradio.com/logo.png",
        "country" => "United States",
        "countrycode" => "US",
        "language" => "english",
        "tags" => "rock,classic",
        "codec" => "MP3",
        "bitrate" => 128,
        "votes" => 500
      },
      {
        "stationuuid" => "def-456",
        "name" => "Jazz FM",
        "url_resolved" => "https://stream.example.com/jazz.mp3",
        "url" => "https://stream.example.com/jazz.mp3",
        "homepage" => "",
        "favicon" => "",
        "country" => "United States",
        "countrycode" => "US",
        "language" => "english",
        "tags" => "jazz,smooth",
        "codec" => "AAC",
        "bitrate" => 192,
        "votes" => 300
      }
    ]
  end

  before do
    stub_request(:get, /de1\.api\.radio-browser\.info/)
      .to_return(body: api_response.to_json, headers: {"Content-Type" => "application/json"})
  end

  describe "#call" do
    it "imports stations by country code" do
      result = described_class.new(country_code: "US").call

      expect(result[:synced]).to eq(2)
      expect(InternetRadioStation.count).to eq(2)
    end

    it "imports stations by tag" do
      result = described_class.new(tag: "rock").call

      expect(result[:synced]).to eq(2)
      expect(InternetRadioStation.count).to eq(2)
    end

    it "creates categories from tags" do
      described_class.new(country_code: "US").call

      expect(InternetRadioCategory.pluck(:name)).to contain_exactly("rock", "jazz")
    end

    it "upserts on uuid — updates existing stations" do
      create(:internet_radio_station, uuid: "abc-123", name: "Old Name", stream_url: "https://old.example.com")

      result = described_class.new(country_code: "US").call

      expect(result[:synced]).to eq(2)
      expect(InternetRadioStation.find_by(uuid: "abc-123").name).to eq("Test Radio")
    end

    it "skips entries without stationuuid" do
      api_response << {"stationuuid" => "", "name" => "No UUID", "url_resolved" => "https://x.com/s.mp3"}
      stub_request(:get, /de1\.api\.radio-browser\.info/)
        .to_return(body: api_response.to_json, headers: {"Content-Type" => "application/json"})

      result = described_class.new(country_code: "US").call
      expect(result[:synced]).to eq(2)
    end

    it "skips entries without a stream URL" do
      api_response << {"stationuuid" => "no-url-1", "name" => "No URL", "url_resolved" => "", "url" => ""}
      stub_request(:get, /de1\.api\.radio-browser\.info/)
        .to_return(body: api_response.to_json, headers: {"Content-Type" => "application/json"})

      result = described_class.new(country_code: "US").call
      expect(result[:synced]).to eq(2)
    end
  end
end
