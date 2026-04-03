require "rails_helper"

RSpec.describe DiscographyMergeService do
  let(:artist) { create(:artist) }

  let(:discography) do
    [
      {mbid: "rg-1", title: "Violator", year: 1990, type: "Album", cover_art_url: "https://example.com/rg-1.jpg"},
      {mbid: "rg-2", title: "Songs of Faith and Devotion", year: 1993, type: "Album", cover_art_url: "https://example.com/rg-2.jpg"},
      {mbid: "rg-3", title: "Ultra", year: 1997, type: "Album", cover_art_url: "https://example.com/rg-3.jpg"}
    ]
  end

  describe ".call" do
    it "marks owned albums and missing albums" do
      owned = create(:album, artist: artist, title: "Violator", year: 1990)

      entries = described_class.call(artist, [owned], discography)

      owned_entries = entries.select { |e| e[:type] == :owned }
      missing_entries = entries.select { |e| e[:type] == :missing }

      expect(owned_entries.length).to eq(1)
      expect(owned_entries.first[:album]).to eq(owned)
      expect(missing_entries.length).to eq(2)
      expect(missing_entries.map { |e| e[:title] }).to contain_exactly("Songs of Faith and Devotion", "Ultra")
    end

    it "matches by normalized title (case insensitive, stripped punctuation)" do
      owned = create(:album, artist: artist, title: "Songs Of Faith And Devotion!", year: 1993)

      entries = described_class.call(artist, [owned], discography)
      missing_titles = entries.select { |e| e[:type] == :missing }.map { |e| e[:title] }

      expect(missing_titles).not_to include("Songs of Faith and Devotion")
      expect(missing_titles).to contain_exactly("Violator", "Ultra")
    end

    it "matches by musicbrainz_release_id" do
      owned = create(:album, artist: artist, title: "Totally Different Name", year: 1990, musicbrainz_release_id: "rg-1")

      entries = described_class.call(artist, [owned], discography)
      missing_titles = entries.select { |e| e[:type] == :missing }.map { |e| e[:title] }

      expect(missing_titles).not_to include("Violator")
    end

    it "includes owned albums without MusicBrainz match" do
      owned = create(:album, artist: artist, title: "Local Only Album", year: 2020)

      entries = described_class.call(artist, [owned], discography)
      owned_entries = entries.select { |e| e[:type] == :owned }

      expect(owned_entries.length).to eq(1)
      expect(owned_entries.first[:album].title).to eq("Local Only Album")
    end

    it "sorts by year then title" do
      owned_1997 = create(:album, artist: artist, title: "Ultra", year: 1997)
      owned_1990 = create(:album, artist: artist, title: "Violator", year: 1990)

      entries = described_class.call(artist, [owned_1997, owned_1990], discography)
      years = entries.map { |e| e[:year] }

      expect(years).to eq([1990, 1993, 1997])
    end

    it "puts albums without year at the end" do
      owned = create(:album, artist: artist, title: "No Year Album", year: nil)
      no_year_disco = [{mbid: "rg-x", title: "Mystery", year: nil, type: "Album", cover_art_url: ""}]

      entries = described_class.call(artist, [owned], discography + no_year_disco)
      last_two = entries.last(2)

      expect(last_two.all? { |e| e[:year].nil? }).to be true
    end

    it "returns only owned entries when discography is empty" do
      owned = create(:album, artist: artist, title: "My Album", year: 2020)

      entries = described_class.call(artist, [owned], [])

      expect(entries.length).to eq(1)
      expect(entries.first[:type]).to eq(:owned)
    end
  end
end
