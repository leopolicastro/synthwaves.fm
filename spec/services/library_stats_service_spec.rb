require "rails_helper"

RSpec.describe LibraryStatsService do
  let(:user) { create(:user) }
  let(:artist) { create(:artist, name: "Neon Runner", user: user) }
  let(:album) { create(:album, artist: artist, user: user, genre: "Synthwave") }

  describe ".call" do
    it "returns a hash with all expected keys" do
      result = described_class.call(user: user)

      expect(result).to include(
        :track_count, :album_count, :artist_count,
        :total_duration, :total_file_size, :avg_track_duration,
        :top_genres
      )
    end
  end

  describe "counts" do
    it "counts tracks, albums, and artists" do
      create(:track, album: album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user)

      result = described_class.call(user: user)

      expect(result[:track_count]).to eq(2)
      expect(result[:album_count]).to eq(1)
      expect(result[:artist_count]).to eq(1)
    end

    it "excludes other users' data" do
      other_user = create(:user)
      other_artist = create(:artist, user: other_user)
      other_album = create(:album, artist: other_artist, user: other_user)
      create(:track, album: other_album, artist: other_artist, user: other_user)

      create(:track, album: album, artist: artist, user: user)

      result = described_class.call(user: user)

      expect(result[:track_count]).to eq(1)
      expect(result[:album_count]).to eq(1)
      expect(result[:artist_count]).to eq(1)
    end

    it "returns zeros for an empty library" do
      result = described_class.call(user: user)

      expect(result[:track_count]).to eq(0)
      expect(result[:album_count]).to eq(0)
      expect(result[:artist_count]).to eq(0)
    end
  end

  describe "total_duration" do
    it "sums track durations" do
      create(:track, album: album, artist: artist, user: user, duration: 240.0)
      create(:track, album: album, artist: artist, user: user, duration: 180.0)

      result = described_class.call(user: user)

      expect(result[:total_duration]).to eq(420.0)
    end

    it "returns 0.0 for an empty library" do
      result = described_class.call(user: user)

      expect(result[:total_duration]).to eq(0.0)
    end
  end

  describe "total_file_size" do
    it "sums file sizes" do
      create(:track, album: album, artist: artist, user: user, file_size: 5_000_000)
      create(:track, album: album, artist: artist, user: user, file_size: 3_000_000)

      result = described_class.call(user: user)

      expect(result[:total_file_size]).to eq(8_000_000)
    end
  end

  describe "avg_track_duration" do
    it "averages track durations" do
      create(:track, album: album, artist: artist, user: user, duration: 240.0)
      create(:track, album: album, artist: artist, user: user, duration: 180.0)

      result = described_class.call(user: user)

      expect(result[:avg_track_duration]).to eq(210.0)
    end

    it "returns 0.0 for an empty library" do
      result = described_class.call(user: user)

      expect(result[:avg_track_duration]).to eq(0.0)
    end
  end

  describe "top_genres" do
    it "returns genres ordered by track count" do
      album2 = create(:album, artist: artist, user: user, genre: "Darkwave")

      create(:track, album: album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user)
      create(:track, album: album2, artist: artist, user: user)

      result = described_class.call(user: user)

      genres = result[:top_genres]
      expect(genres.keys.first).to eq("Synthwave")
      expect(genres["Synthwave"]).to eq(3)
      expect(genres["Darkwave"]).to eq(1)
    end

    it "excludes nil and empty genres" do
      album_nil = create(:album, artist: artist, user: user, genre: nil)
      album_empty = create(:album, artist: artist, user: user, genre: "")

      create(:track, album: album_nil, artist: artist, user: user)
      create(:track, album: album_empty, artist: artist, user: user)

      result = described_class.call(user: user)

      expect(result[:top_genres]).to be_empty
    end
  end
end
