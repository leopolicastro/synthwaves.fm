require "rails_helper"

RSpec.describe SearchService, type: :service do
  describe ".call" do
    let!(:artist) { create(:artist, name: "The Beatles") }
    let!(:album) { create(:album, title: "Abbey Road", artist: artist) }
    let!(:track) { create(:track, title: "Come Together", album: album, artist: artist) }

    it "finds artists by name" do
      results = described_class.call(query: "Beatles")
      expect(results[:artists]).to include(artist)
    end

    it "finds albums by title" do
      results = described_class.call(query: "Abbey")
      expect(results[:albums]).to include(album)
    end

    it "finds tracks by title" do
      results = described_class.call(query: "Together")
      expect(results[:tracks]).to include(track)
    end

    it "returns empty results for no match" do
      results = described_class.call(query: "zzzzzzz")
      expect(results[:artists]).to be_empty
      expect(results[:albums]).to be_empty
      expect(results[:tracks]).to be_empty
    end

    it "respects type filter" do
      results = described_class.call(query: "Beatles", types: [:artist])
      expect(results[:artists]).to include(artist)
      expect(results[:albums]).to be_empty
      expect(results[:tracks]).to be_empty
    end
  end
end
