require "rails_helper"

RSpec.describe "PlaylistTracks", type: :request do
  describe "POST /playlists/:playlist_id/tracks" do
    it "requires authentication" do
      playlist = create(:playlist)
      track = create(:track)
      post playlist_tracks_path(playlist), params: {track_id: track.id}
      expect(response).to redirect_to(new_session_path)
    end

    it "adds a track to the playlist" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      track = create(:track, album: create(:album, artist: create(:artist, user: user)))

      expect {
        post playlist_tracks_path(playlist), params: {track_id: track.id}
      }.to change(playlist.playlist_tracks, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(playlist.tracks).to include(track)
    end

    it "assigns the next position automatically" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user)
      track1 = create(:track, album: create(:album, artist: artist))
      track2 = create(:track, album: create(:album, artist: artist))

      post playlist_tracks_path(playlist), params: {track_id: track1.id}
      post playlist_tracks_path(playlist), params: {track_id: track2.id}

      positions = playlist.playlist_tracks.order(:position).pluck(:position)
      expect(positions).to eq([1, 2])
    end

    it "does not add the same track twice" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      track = create(:track, album: create(:album, artist: create(:artist, user: user)))
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      expect {
        post playlist_tracks_path(playlist), params: {track_id: track.id}
      }.not_to change(playlist.playlist_tracks, :count)
    end

    it "cannot add tracks to another user's playlist" do
      user = create(:user)
      other_user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: other_user)
      track = create(:track, album: create(:album, artist: create(:artist, user: user)))

      post playlist_tracks_path(playlist), params: {track_id: track.id}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /playlists/:playlist_id/tracks with album_id" do
    it "adds all album tracks to the playlist in disc/track order" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      album = create(:album, artist: create(:artist, user: user))
      track3 = create(:track, album: album, disc_number: 2, track_number: 1)
      track1 = create(:track, album: album, disc_number: 1, track_number: 1)
      track2 = create(:track, album: album, disc_number: 1, track_number: 2)

      expect {
        post playlist_tracks_path(playlist), params: {album_id: album.id}
      }.to change(playlist.playlist_tracks, :count).by(3)

      expect(playlist.playlist_tracks.order(:position).map(&:track)).to eq([track1, track2, track3])
    end

    it "skips tracks already in the playlist" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      album = create(:album, artist: create(:artist, user: user))
      track1 = create(:track, album: album, disc_number: 1, track_number: 1)
      track2 = create(:track, album: album, disc_number: 1, track_number: 2)
      create(:playlist_track, playlist: playlist, track: track1, position: 1)

      expect {
        post playlist_tracks_path(playlist), params: {album_id: album.id}
      }.to change(playlist.playlist_tracks, :count).by(1)

      expect(playlist.playlist_tracks.order(:position).map(&:track)).to eq([track1, track2])
    end

    it "assigns positions after existing tracks" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user)
      existing_track = create(:track, album: create(:album, artist: artist))
      create(:playlist_track, playlist: playlist, track: existing_track, position: 5)

      album = create(:album, artist: artist)
      create(:track, album: album, disc_number: 1, track_number: 1)

      post playlist_tracks_path(playlist), params: {album_id: album.id}

      positions = playlist.playlist_tracks.order(:position).pluck(:position)
      expect(positions).to eq([5, 6])
    end
  end

  describe "POST /playlists/:playlist_id/tracks with track_ids" do
    it "adds multiple tracks to the playlist" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user)
      track1 = create(:track, album: create(:album, artist: artist))
      track2 = create(:track, album: create(:album, artist: artist))
      track3 = create(:track, album: create(:album, artist: artist))

      expect {
        post playlist_tracks_path(playlist), params: {track_ids: [track1.id, track2.id, track3.id]}
      }.to change(playlist.playlist_tracks, :count).by(3)

      expect(playlist.playlist_tracks.order(:position).map(&:track)).to eq([track1, track2, track3])
    end

    it "skips tracks already in the playlist" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user)
      track1 = create(:track, album: create(:album, artist: artist))
      track2 = create(:track, album: create(:album, artist: artist))
      create(:playlist_track, playlist: playlist, track: track1, position: 1)

      expect {
        post playlist_tracks_path(playlist), params: {track_ids: [track1.id, track2.id]}
      }.to change(playlist.playlist_tracks, :count).by(1)

      expect(playlist.playlist_tracks.order(:position).map(&:track)).to eq([track1, track2])
    end

    it "assigns positions after existing tracks" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user)
      existing_track = create(:track, album: create(:album, artist: artist))
      create(:playlist_track, playlist: playlist, track: existing_track, position: 5)

      track1 = create(:track, album: create(:album, artist: artist))
      track2 = create(:track, album: create(:album, artist: artist))

      post playlist_tracks_path(playlist), params: {track_ids: [track1.id, track2.id]}

      positions = playlist.playlist_tracks.order(:position).pluck(:position)
      expect(positions).to eq([5, 6, 7])
    end

    it "ignores invalid track IDs" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      track = create(:track, album: create(:album, artist: create(:artist, user: user)))

      expect {
        post playlist_tracks_path(playlist), params: {track_ids: [track.id, 999999]}
      }.to change(playlist.playlist_tracks, :count).by(1)
    end
  end

  describe "DELETE /playlists/:playlist_id/tracks/:id" do
    it "requires authentication" do
      playlist = create(:playlist)
      pt = create(:playlist_track, playlist: playlist, position: 1)
      delete playlist_track_path(playlist, pt)
      expect(response).to redirect_to(new_session_path)
    end

    it "removes the track from the playlist" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      pt = create(:playlist_track, playlist: playlist, position: 1)

      expect {
        delete playlist_track_path(playlist, pt)
      }.to change(playlist.playlist_tracks, :count).by(-1)

      expect(response).to have_http_status(:redirect)
    end
  end
end
