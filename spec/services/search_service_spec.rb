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

    context "category filter" do
      let!(:podcast_artist) { create(:artist, :podcast, name: "Podcast Show") }
      let!(:podcast_album) { create(:album, title: "Podcast Season 1", artist: podcast_artist) }
      let!(:podcast_track) { create(:track, title: "Podcast Episode 1", album: podcast_album, artist: podcast_artist) }

      it "defaults to music and excludes podcast content" do
        results = described_class.call(query: "Podcast")
        expect(results[:artists]).to be_empty
        expect(results[:albums]).to be_empty
        expect(results[:tracks]).to be_empty
      end

      it "finds podcast content when category is podcast" do
        results = described_class.call(query: "Podcast", category: "podcast")
        expect(results[:artists]).to include(podcast_artist)
        expect(results[:albums]).to include(podcast_album)
        expect(results[:tracks]).to include(podcast_track)
      end

      it "finds music content with default category" do
        results = described_class.call(query: "Beatles")
        expect(results[:artists]).to include(artist)
      end
    end

    context "genre filter" do
      let!(:electronic_album) { create(:album, title: "Synthwave Dreams", artist: artist, genre: "Electronic") }
      let!(:electronic_track) { create(:track, title: "Neon Pulse", album: electronic_album, artist: artist) }
      let!(:rock_album) { create(:album, title: "Rock Anthems", artist: create(:artist, name: "Rock Band"), genre: "Rock") }
      let!(:rock_track) { create(:track, title: "Thunder Road", album: rock_album, artist: rock_album.artist) }

      it "filters albums by genre" do
        results = described_class.call(query: "Dreams", genre: "Electronic")
        expect(results[:albums]).to include(electronic_album)
      end

      it "excludes albums not matching genre" do
        results = described_class.call(query: "Anthems", genre: "Electronic")
        expect(results[:albums]).to be_empty
      end

      it "filters tracks by their album's genre" do
        results = described_class.call(query: "Neon", genre: "Electronic")
        expect(results[:tracks]).to include(electronic_track)
      end

      it "excludes tracks whose album does not match genre" do
        results = described_class.call(query: "Thunder", genre: "Electronic")
        expect(results[:tracks]).to be_empty
      end

      it "does not filter artists by genre" do
        results = described_class.call(query: "Rock Band", genre: "Electronic")
        expect(results[:artists]).to include(rock_album.artist)
      end
    end

    context "year range filter" do
      let!(:old_album) { create(:album, title: "Retro Vibes", artist: artist, year: 2010) }
      let!(:new_album) { create(:album, title: "Modern Beats", artist: artist, year: 2023) }
      let!(:old_track) { create(:track, title: "Oldschool Jam", album: old_album, artist: artist) }
      let!(:new_track) { create(:track, title: "Fresh Sound", album: new_album, artist: artist) }

      it "filters albums with year_from" do
        results = described_class.call(query: "Vibes", year_from: 2015)
        expect(results[:albums]).to be_empty
      end

      it "includes albums at the year_from boundary" do
        results = described_class.call(query: "Retro", year_from: 2010)
        expect(results[:albums]).to include(old_album)
      end

      it "filters albums with year_to" do
        results = described_class.call(query: "Modern", year_to: 2020)
        expect(results[:albums]).to be_empty
      end

      it "includes albums at the year_to boundary" do
        results = described_class.call(query: "Modern", year_to: 2023)
        expect(results[:albums]).to include(new_album)
      end

      it "filters albums with both year_from and year_to" do
        results = described_class.call(query: "Vibes", year_from: 2015, year_to: 2025)
        expect(results[:albums]).to be_empty

        results = described_class.call(query: "Beats", year_from: 2015, year_to: 2025)
        expect(results[:albums]).to include(new_album)
      end

      it "filters tracks by their album's year" do
        results = described_class.call(query: "Jam", year_from: 2015)
        expect(results[:tracks]).to be_empty

        results = described_class.call(query: "Fresh", year_from: 2015)
        expect(results[:tracks]).to include(new_track)
      end

      it "does not filter artists by year" do
        results = described_class.call(query: "Beatles", year_from: 2050)
        expect(results[:artists]).to include(artist)
      end
    end

    context "favorites only filter" do
      let(:user) { create(:user) }
      let!(:fav_album) { create(:album, title: "Loved Album", artist: artist, user: user) }
      let!(:unfav_album) { create(:album, title: "Unloved Album", artist: artist, user: user) }
      let!(:fav_track) { create(:track, title: "Loved Song", album: fav_album, artist: artist, user: user) }
      let!(:unfav_track) { create(:track, title: "Unloved Song", album: unfav_album, artist: artist, user: user) }
      let!(:fav_artist) { create(:artist, name: "Beloved Artist", user: user) }
      let!(:unfav_artist) { create(:artist, name: "Unknown Artist", user: user) }

      before do
        create(:favorite, user: user, favorable: fav_album)
        create(:favorite, user: user, favorable: fav_track)
        create(:favorite, user: user, favorable: fav_artist)
      end

      it "returns only favorited albums" do
        results = described_class.call(query: "Album", favorites_only: true, user: user)
        expect(results[:albums]).to include(fav_album)
        expect(results[:albums]).not_to include(unfav_album)
      end

      it "returns only favorited tracks" do
        results = described_class.call(query: "Song", favorites_only: true, user: user)
        expect(results[:tracks]).to include(fav_track)
        expect(results[:tracks]).not_to include(unfav_track)
      end

      it "returns only favorited artists" do
        results = described_class.call(query: "Artist", favorites_only: true, user: user)
        expect(results[:artists]).to include(fav_artist)
        expect(results[:artists]).not_to include(unfav_artist)
      end

      it "returns all results when favorites_only is false" do
        results = described_class.call(query: "Album", favorites_only: false, user: user)
        expect(results[:albums]).to include(fav_album, unfav_album)
      end
    end

    context "combined filters" do
      let(:user) { create(:user) }
      let!(:matching_album) { create(:album, title: "Perfect Match", artist: artist, genre: "Electronic", year: 2022, user: user) }
      let!(:wrong_genre_album) { create(:album, title: "Perfect Miss", artist: artist, genre: "Rock", year: 2022, user: user) }
      let!(:wrong_year_album) { create(:album, title: "Perfect Old", artist: artist, genre: "Electronic", year: 2010, user: user) }
      let!(:matching_track) { create(:track, title: "Hit Song", album: matching_album, artist: artist, user: user) }
      let!(:wrong_genre_track) { create(:track, title: "Hit Rock", album: wrong_genre_album, artist: artist, user: user) }

      before do
        create(:favorite, user: user, favorable: matching_album)
        create(:favorite, user: user, favorable: matching_track)
      end

      it "applies genre, year, and favorites filters together" do
        results = described_class.call(
          query: "Perfect",
          genre: "Electronic",
          year_from: 2020,
          year_to: 2025,
          favorites_only: true,
          user: user
        )
        expect(results[:albums]).to eq([matching_album])
      end

      it "applies genre and year filters to tracks" do
        results = described_class.call(
          query: "Hit",
          genre: "Electronic",
          year_from: 2020
        )
        expect(results[:tracks]).to include(matching_track)
        expect(results[:tracks]).not_to include(wrong_genre_track)
      end
    end
  end
end
