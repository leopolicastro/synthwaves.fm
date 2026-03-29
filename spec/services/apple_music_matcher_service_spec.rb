require "rails_helper"

RSpec.describe AppleMusicMatcherService do
  let(:track) { create(:track, title: "Get Lucky", duration: 369.0, track_number: 8) }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:apple_music_musickit).and_return(false)
  end

  describe ".call" do
    it "returns the best matching result above threshold" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: hash_including(entity: "song"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            resultCount: 1,
            results: [{
              trackId: 123,
              trackName: "Get Lucky",
              artistName: track.artist.name,
              collectionName: "Random Access Memories",
              primaryGenreName: "Electronic",
              trackExplicitness: "notExplicit",
              releaseDate: "2013-05-17T07:00:00Z",
              trackTimeMillis: 369000,
              discNumber: 1,
              trackNumber: 8
            }]
          }.to_json
        )

      result = described_class.call(track)

      expect(result).not_to be_nil
      expect(result[:apple_music_id]).to eq("123")
      expect(result[:name]).to eq("Get Lucky")
    end

    it "returns nil when no results match above threshold" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: hash_including(entity: "song"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            resultCount: 1,
            results: [{
              trackId: 999,
              trackName: "Completely Different Song",
              artistName: "Different Artist",
              collectionName: "Different Album",
              primaryGenreName: "Pop",
              trackExplicitness: "notExplicit",
              releaseDate: "2020-01-01T07:00:00Z",
              trackTimeMillis: 200000,
              discNumber: 1,
              trackNumber: 1
            }]
          }.to_json
        )

      result = described_class.call(track)
      expect(result).to be_nil
    end

    it "returns nil when search returns no results" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: hash_including(entity: "song"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {resultCount: 0, results: []}.to_json
        )

      result = described_class.call(track)
      expect(result).to be_nil
    end
  end
end
