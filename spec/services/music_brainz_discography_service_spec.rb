require "rails_helper"

RSpec.describe MusicBrainzDiscographyService do
  let(:artist_mbid) { "artist-456" }

  before do
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  describe ".call" do
    it "returns parsed release groups sorted by year" do
      stub_request(:get, "https://musicbrainz.org/ws/2/release-group")
        .with(query: hash_including(artist: artist_mbid, type: "album", fmt: "json"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "release-group-count" => 2,
            "release-groups" => [
              {
                "id" => "rg-2",
                "title" => "Songs of Faith and Devotion",
                "primary-type" => "Album",
                "first-release-date" => "1993-03-22"
              },
              {
                "id" => "rg-1",
                "title" => "Violator",
                "primary-type" => "Album",
                "first-release-date" => "1990-03-19"
              }
            ]
          }.to_json
        )

      results = described_class.call(artist_mbid)

      expect(results.length).to eq(2)
      expect(results.first[:title]).to eq("Violator")
      expect(results.first[:year]).to eq(1990)
      expect(results.first[:mbid]).to eq("rg-1")
      expect(results.first[:cover_art_url]).to include("rg-1")
      expect(results.last[:title]).to eq("Songs of Faith and Devotion")
      expect(results.last[:year]).to eq(1993)
    end

    it "caches results for 7 days" do
      cache_store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(cache_store)

      stub = stub_request(:get, "https://musicbrainz.org/ws/2/release-group")
        .with(query: hash_including(artist: artist_mbid))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {"release-group-count" => 0, "release-groups" => []}.to_json
        )

      described_class.call(artist_mbid)
      described_class.call(artist_mbid)

      expect(stub).to have_been_requested.once
    end

    it "returns empty array for unknown artist" do
      stub_request(:get, "https://musicbrainz.org/ws/2/release-group")
        .with(query: hash_including(artist: artist_mbid))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {"release-group-count" => 0, "release-groups" => []}.to_json
        )

      results = described_class.call(artist_mbid)
      expect(results).to eq([])
    end

    it "raises MusicBrainzService::Error on API failure" do
      stub_request(:get, "https://musicbrainz.org/ws/2/release-group")
        .with(query: hash_including(artist: artist_mbid))
        .to_return(status: 503, body: "Service Unavailable")

      expect { described_class.call(artist_mbid) }
        .to raise_error(MusicBrainzService::Error, /503/)
    end

    it "handles release groups with no date" do
      stub_request(:get, "https://musicbrainz.org/ws/2/release-group")
        .with(query: hash_including(artist: artist_mbid))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "release-group-count" => 1,
            "release-groups" => [
              {"id" => "rg-no-date", "title" => "Untitled", "primary-type" => "Album", "first-release-date" => ""}
            ]
          }.to_json
        )

      results = described_class.call(artist_mbid)
      expect(results.first[:year]).to be_nil
    end
  end
end
