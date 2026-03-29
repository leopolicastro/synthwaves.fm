require "rails_helper"

RSpec.describe AppleMusicService do
  let(:service) { described_class.new(storefront: "us") }

  describe "#search_song via iTunes Search API (default)" do
    before do
      allow(Flipper).to receive(:enabled?).with(:apple_music_musickit).and_return(false)
    end

    it "returns parsed song results" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: {term: "Daft Punk Get Lucky", entity: "song", limit: 5})
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            resultCount: 1,
            results: [{
              trackId: 1234567890,
              trackName: "Get Lucky",
              artistName: "Daft Punk",
              collectionName: "Random Access Memories",
              primaryGenreName: "Pop",
              trackExplicitness: "notExplicit",
              releaseDate: "2013-05-17T07:00:00Z",
              trackTimeMillis: 369000,
              discNumber: 1,
              trackNumber: 8
            }]
          }.to_json
        )

      results = service.search_song(artist: "Daft Punk", title: "Get Lucky")

      expect(results.length).to eq(1)
      expect(results.first[:apple_music_id]).to eq("1234567890")
      expect(results.first[:name]).to eq("Get Lucky")
      expect(results.first[:artist_name]).to eq("Daft Punk")
      expect(results.first[:genre_names]).to eq(["Pop"])
      expect(results.first[:isrc]).to be_nil
      expect(results.first[:release_date]).to eq("2013-05-17")
      expect(results.first[:duration_ms]).to eq(369000)
    end

    it "returns empty array when no results" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: hash_including(term: "Unknown Artist Unknown Song"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {resultCount: 0, results: []}.to_json
        )

      results = service.search_song(artist: "Unknown Artist", title: "Unknown Song")
      expect(results).to eq([])
    end

    it "raises Error on API failure" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: hash_including(term: "test test"))
        .to_return(status: 503, body: "Service Unavailable")

      expect { service.search_song(artist: "test", title: "test") }
        .to raise_error(AppleMusicService::Error, /503/)
    end
  end

  describe "#search_song via MusicKit API" do
    before do
      allow(Flipper).to receive(:enabled?).with(:apple_music_musickit).and_return(true)
      allow(AppleMusicTokenService).to receive(:token).and_return("test-token")
    end

    it "returns parsed song results with richer metadata" do
      stub_request(:get, "https://api.music.apple.com/v1/catalog/us/search")
        .with(
          query: {term: "Daft Punk Get Lucky", types: "songs", limit: 5},
          headers: {"Authorization" => "Bearer test-token"}
        )
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            results: {
              songs: {
                data: [{
                  id: "1234567890",
                  attributes: {
                    name: "Get Lucky",
                    artistName: "Daft Punk",
                    albumName: "Random Access Memories",
                    genreNames: ["Electronic", "Dance", "Music"],
                    isrc: "USCO11300095",
                    contentRating: nil,
                    releaseDate: "2013-05-17",
                    durationInMillis: 369000,
                    discNumber: 1,
                    trackNumber: 8,
                    composerName: "Thomas Bangalter"
                  }
                }]
              }
            }
          }.to_json
        )

      results = service.search_song(artist: "Daft Punk", title: "Get Lucky")

      expect(results.first[:genre_names]).to eq(["Electronic", "Dance", "Music"])
      expect(results.first[:isrc]).to eq("USCO11300095")
      expect(results.first[:composer_name]).to eq("Thomas Bangalter")
    end
  end
end
