require "rails_helper"

RSpec.describe MusicBrainzService do
  let(:service) { described_class.new }

  before do
    allow(service).to receive(:sleep)
  end

  describe "#search_recording" do
    it "returns parsed recording results" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(
          query: hash_including(fmt: "json"),
          headers: {"User-Agent" => MusicBrainzService::USER_AGENT}
        )
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "recordings" => [{
              "id" => "abc-123",
              "title" => "Enjoy the Silence",
              "length" => 373000,
              "artist-credit" => [{
                "name" => "Depeche Mode",
                "artist" => {"id" => "artist-456", "name" => "Depeche Mode"}
              }],
              "releases" => [{
                "id" => "release-789",
                "title" => "Violator",
                "date" => "1990-03-19",
                "country" => "GB"
              }],
              "tags" => [
                {"name" => "synthpop", "count" => 5},
                {"name" => "electronic", "count" => 3}
              ]
            }]
          }.to_json
        )

      results = service.search_recording(artist: "Depeche Mode", title: "Enjoy the Silence")

      expect(results.length).to eq(1)
      expect(results.first[:mbid]).to eq("abc-123")
      expect(results.first[:title]).to eq("Enjoy the Silence")
      expect(results.first[:artist_name]).to eq("Depeche Mode")
      expect(results.first[:artist_mbid]).to eq("artist-456")
      expect(results.first[:duration_ms]).to eq(373000)
      expect(results.first[:tags]).to eq(["synthpop", "electronic"])
      expect(results.first[:releases].first[:mbid]).to eq("release-789")
      expect(results.first[:releases].first[:title]).to eq("Violator")
    end

    it "returns empty array when no results" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(query: hash_including(fmt: "json"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {recordings: []}.to_json
        )

      results = service.search_recording(artist: "Unknown", title: "Unknown")
      expect(results).to eq([])
    end

    it "raises Error on API failure" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(query: hash_including(fmt: "json"))
        .to_return(status: 503, body: "Service Unavailable")

      expect { service.search_recording(artist: "test", title: "test") }
        .to raise_error(MusicBrainzService::Error, /503/)
    end

    it "raises Error on connection failure" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(query: hash_including(fmt: "json"))
        .to_raise(HTTP::ConnectionError.new("connection refused"))

      expect { service.search_recording(artist: "test", title: "test") }
        .to raise_error(MusicBrainzService::Error, /connection refused/)
    end

    it "filters out tags with count below 1" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(query: hash_including(fmt: "json"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "recordings" => [{
              "id" => "abc-123",
              "title" => "Test",
              "artist-credit" => [{"name" => "Test", "artist" => {"id" => "a1", "name" => "Test"}}],
              "tags" => [
                {"name" => "rock", "count" => 3},
                {"name" => "spam-tag", "count" => 0}
              ]
            }]
          }.to_json
        )

      results = service.search_recording(artist: "Test", title: "Test")
      expect(results.first[:tags]).to eq(["rock"])
    end
  end

  describe "#search_recording_by_isrc" do
    it "returns results for a valid ISRC" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(query: hash_including(fmt: "json"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "recordings" => [{
              "id" => "isrc-match-123",
              "title" => "Enjoy the Silence",
              "artist-credit" => [{"name" => "Depeche Mode", "artist" => {"id" => "a1", "name" => "Depeche Mode"}}],
              "releases" => []
            }]
          }.to_json
        )

      results = service.search_recording_by_isrc(isrc: "GBAYE9000123")
      expect(results.first[:mbid]).to eq("isrc-match-123")
    end
  end

  describe "rate limiting" do
    it "sleeps between each API request" do
      stub_request(:get, "https://musicbrainz.org/ws/2/recording")
        .with(query: hash_including(fmt: "json"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {recordings: []}.to_json
        )

      service.search_recording(artist: "test", title: "test")

      expect(service).to have_received(:sleep).with(MusicBrainzService::MIN_REQUEST_INTERVAL)
    end
  end
end
