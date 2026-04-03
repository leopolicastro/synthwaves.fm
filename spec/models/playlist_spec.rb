require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:playlist_tracks).dependent(:destroy) }
    it { should have_many(:tracks).through(:playlist_tracks) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe "#random_cover_track" do
    let(:user) { create(:user) }
    let(:playlist) { create(:playlist, user: user) }

    it "returns nil for an empty playlist" do
      expect(playlist.random_cover_track).to be_nil
    end

    it "returns nil when no albums have cover images" do
      track = create(:track)
      create(:playlist_track, playlist: playlist, track: track)

      expect(playlist.random_cover_track).to be_nil
    end

    it "returns a track whose album has a cover image" do
      album_with_cover = create(:album)
      album_with_cover.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )
      track_with_cover = create(:track, album: album_with_cover, artist: album_with_cover.artist)
      create(:playlist_track, playlist: playlist, track: track_with_cover)

      track_without_cover = create(:track)
      create(:playlist_track, playlist: playlist, track: track_without_cover)

      expect(playlist.random_cover_track).to eq(track_with_cover)
    end
  end

  describe "#cover_albums" do
    let(:user) { create(:user) }
    let(:playlist) { create(:playlist, user: user) }

    def album_with_cover
      album = create(:album)
      album.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )
      album
    end

    it "returns empty for an empty playlist" do
      expect(playlist.cover_albums).to be_empty
    end

    it "returns albums that have cover images" do
      album = album_with_cover
      track = create(:track, album: album, artist: album.artist)
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      expect(playlist.cover_albums).to contain_exactly(album)
    end

    it "excludes albums without cover images" do
      track = create(:track)
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      expect(playlist.cover_albums).to be_empty
    end

    it "deduplicates albums with multiple tracks" do
      album = album_with_cover
      track1 = create(:track, album: album, artist: album.artist)
      track2 = create(:track, album: album, artist: album.artist)
      create(:playlist_track, playlist: playlist, track: track1, position: 1)
      create(:playlist_track, playlist: playlist, track: track2, position: 2)

      expect(playlist.cover_albums).to contain_exactly(album)
    end

    it "respects the limit parameter" do
      5.times do |i|
        album = album_with_cover
        track = create(:track, album: album, artist: album.artist)
        create(:playlist_track, playlist: playlist, track: track, position: i + 1)
      end

      expect(playlist.cover_albums.size).to eq(4)
      expect(playlist.cover_albums(2).size).to eq(2)
    end
  end

  describe ".preload_cover_albums" do
    let(:user) { create(:user) }

    def album_with_cover
      album = create(:album)
      album.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )
      album
    end

    it "returns empty hash for empty collection" do
      expect(Playlist.preload_cover_albums([])).to eq({})
    end

    it "returns correct albums per playlist" do
      playlist1 = create(:playlist, user: user)
      playlist2 = create(:playlist, user: user)

      album1 = album_with_cover
      album2 = album_with_cover

      create(:playlist_track, playlist: playlist1, track: create(:track, album: album1, artist: album1.artist), position: 1)
      create(:playlist_track, playlist: playlist2, track: create(:track, album: album2, artist: album2.artist), position: 1)

      result = Playlist.preload_cover_albums([playlist1, playlist2])

      expect(result[playlist1.id]).to contain_exactly(album1)
      expect(result[playlist2.id]).to contain_exactly(album2)
    end

    it "returns empty array for playlists without covers" do
      playlist = create(:playlist, user: user)
      track = create(:track)
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      result = Playlist.preload_cover_albums([playlist])

      expect(result[playlist.id]).to eq([])
    end

    it "deduplicates albums and respects limit" do
      playlist = create(:playlist, user: user)
      5.times do |i|
        album = album_with_cover
        track = create(:track, album: album, artist: album.artist)
        create(:playlist_track, playlist: playlist, track: track, position: i + 1)
      end

      result = Playlist.preload_cover_albums([playlist], limit: 3)

      expect(result[playlist.id].size).to eq(3)
    end
  end

  describe "#add_track" do
    let(:user) { create(:user) }
    let(:playlist) { create(:playlist, user: user) }
    let(:track) { create(:track) }

    it "adds a track at the next position" do
      pt = playlist.add_track(track)

      expect(pt).to be_a(PlaylistTrack)
      expect(pt.position).to eq(1)
      expect(playlist.tracks).to include(track)
    end

    it "appends after existing tracks" do
      existing = create(:track)
      playlist.playlist_tracks.create!(track: existing, position: 5)

      pt = playlist.add_track(track)

      expect(pt.position).to eq(6)
    end

    it "skips duplicate tracks and returns nil" do
      playlist.playlist_tracks.create!(track: track, position: 1)

      expect(playlist.add_track(track)).to be_nil
      expect(playlist.playlist_tracks.count).to eq(1)
    end
  end

  describe "#add_tracks" do
    let(:user) { create(:user) }
    let(:playlist) { create(:playlist, user: user) }
    let(:track1) { create(:track) }
    let(:track2) { create(:track) }
    let(:track3) { create(:track) }

    it "adds multiple tracks in order" do
      count = playlist.add_tracks([track1, track2, track3])

      expect(count).to eq(3)
      positions = playlist.playlist_tracks.order(:position).pluck(:track_id, :position)
      expect(positions).to eq([[track1.id, 1], [track2.id, 2], [track3.id, 3]])
    end

    it "skips duplicates and counts only new additions" do
      playlist.playlist_tracks.create!(track: track1, position: 1)

      count = playlist.add_tracks([track1, track2])

      expect(count).to eq(1)
      expect(playlist.playlist_tracks.count).to eq(2)
    end

    it "appends after existing tracks" do
      playlist.playlist_tracks.create!(track: track1, position: 3)

      playlist.add_tracks([track2, track3])

      positions = playlist.playlist_tracks.where(track: [track2, track3]).order(:position).pluck(:position)
      expect(positions).to eq([4, 5])
    end

    it "returns 0 for empty input" do
      expect(playlist.add_tracks([])).to eq(0)
    end
  end

  describe ".search" do
    let(:user) { create(:user) }
    let!(:chill) { create(:playlist, user: user, name: "Chill Vibes") }
    let!(:rock) { create(:playlist, user: user, name: "Rock Anthems") }
    let!(:chill_rock) { create(:playlist, user: user, name: "Chill Rock Mix") }

    it "returns all playlists when query is nil" do
      expect(Playlist.search(nil)).to contain_exactly(chill, rock, chill_rock)
    end

    it "returns all playlists when query is blank" do
      expect(Playlist.search("")).to contain_exactly(chill, rock, chill_rock)
    end

    it "filters playlists by name" do
      expect(Playlist.search("Chill")).to contain_exactly(chill, chill_rock)
    end

    it "is case-insensitive" do
      expect(Playlist.search("chill")).to contain_exactly(chill, chill_rock)
    end

    it "returns empty when no match" do
      expect(Playlist.search("Jazz")).to be_empty
    end
  end
end
