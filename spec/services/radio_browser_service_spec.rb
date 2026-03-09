require "rails_helper"

RSpec.describe RadioBrowserService do
  subject(:service) { described_class.new }

  let(:station_json) do
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
      }
    ]
  end

  describe "#search" do
    it "searches stations by name" do
      stub_request(:get, "https://de1.api.radio-browser.info/json/stations/byname/rock")
        .with(query: hash_including("limit" => "100"))
        .to_return(body: station_json.to_json, headers: {"Content-Type" => "application/json"})

      result = service.search("rock")
      expect(result).to be_an(Array)
      expect(result.first["name"]).to eq("Test Radio")
    end
  end

  describe "#by_country" do
    it "fetches stations by country code" do
      stub_request(:get, "https://de1.api.radio-browser.info/json/stations/bycountrycodeexact/US")
        .with(query: hash_including("limit" => "100"))
        .to_return(body: station_json.to_json, headers: {"Content-Type" => "application/json"})

      result = service.by_country("US")
      expect(result.first["countrycode"]).to eq("US")
    end
  end

  describe "#by_tag" do
    it "fetches stations by tag" do
      stub_request(:get, "https://de1.api.radio-browser.info/json/stations/bytag/rock")
        .with(query: hash_including("limit" => "100"))
        .to_return(body: station_json.to_json, headers: {"Content-Type" => "application/json"})

      result = service.by_tag("rock")
      expect(result.first["tags"]).to include("rock")
    end
  end

  describe "#top_voted" do
    it "fetches top voted stations" do
      stub_request(:get, "https://de1.api.radio-browser.info/json/stations/topvote/100")
        .to_return(body: station_json.to_json, headers: {"Content-Type" => "application/json"})

      result = service.top_voted
      expect(result).to be_an(Array)
    end
  end
end
