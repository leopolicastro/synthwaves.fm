require "rails_helper"

RSpec.describe AppleMusicMatcherService do
  let(:track) { create(:track, title: "Get Lucky", duration: 369.0, track_number: 8) }

  before do
    allow(AppleMusicTokenService).to receive(:token).and_return("test-token")
  end

  describe ".call" do
    it "returns the best matching result above threshold" do
      stub_request(:get, "https://api.music.apple.com/v1/catalog/us/search")
        .with(query: hash_including(types: "songs"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            results: {
              songs: {
                data: [{
                  id: "123",
                  attributes: {
                    name: "Get Lucky",
                    artistName: track.artist.name,
                    albumName: "Random Access Memories",
                    genreNames: ["Electronic"],
                    isrc: nil,
                    contentRating: nil,
                    releaseDate: "2013-05-17",
                    durationInMillis: 369000,
                    discNumber: 1,
                    trackNumber: 8,
                    composerName: nil
                  }
                }]
              }
            }
          }.to_json
        )

      result = described_class.call(track)

      expect(result).not_to be_nil
      expect(result[:apple_music_id]).to eq("123")
      expect(result[:name]).to eq("Get Lucky")
    end

    it "returns nil when no results match above threshold" do
      stub_request(:get, "https://api.music.apple.com/v1/catalog/us/search")
        .with(query: hash_including(types: "songs"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            results: {
              songs: {
                data: [{
                  id: "999",
                  attributes: {
                    name: "Completely Different Song",
                    artistName: "Different Artist",
                    albumName: "Different Album",
                    genreNames: ["Pop"],
                    isrc: nil,
                    contentRating: nil,
                    releaseDate: "2020-01-01",
                    durationInMillis: 200000,
                    discNumber: 1,
                    trackNumber: 1,
                    composerName: nil
                  }
                }]
              }
            }
          }.to_json
        )

      result = described_class.call(track)
      expect(result).to be_nil
    end

    it "returns nil when search returns no results" do
      stub_request(:get, "https://api.music.apple.com/v1/catalog/us/search")
        .with(query: hash_including(types: "songs"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {results: {}}.to_json
        )

      result = described_class.call(track)
      expect(result).to be_nil
    end
  end
end
