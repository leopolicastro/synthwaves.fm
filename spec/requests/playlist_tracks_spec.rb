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
      track = create(:track)

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
      track1 = create(:track)
      track2 = create(:track)

      post playlist_tracks_path(playlist), params: {track_id: track1.id}
      post playlist_tracks_path(playlist), params: {track_id: track2.id}

      positions = playlist.playlist_tracks.order(:position).pluck(:position)
      expect(positions).to eq([1, 2])
    end

    it "does not add the same track twice" do
      user = create(:user)
      login_user(user)
      playlist = create(:playlist, user: user)
      track = create(:track)
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
      track = create(:track)

      post playlist_tracks_path(playlist), params: {track_id: track.id}
      expect(response).to have_http_status(:not_found)
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
