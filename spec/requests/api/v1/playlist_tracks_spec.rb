require "rails_helper"

RSpec.describe "API::V1::PlaylistTracks", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }
  let(:playlist) { create(:playlist, user: user) }

  describe "POST /api/v1/playlists/:playlist_id/tracks" do
    it "adds a single track" do
      track = create(:track, artist: artist, album: album, user: user)

      post "/api/v1/playlists/#{playlist.id}/tracks", params: {track_id: track.id}, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["added"]).to eq(1)
      expect(json["tracks_count"]).to eq(1)
    end

    it "does not duplicate an existing track" do
      track = create(:track, artist: artist, album: album, user: user)
      playlist.add_track(track)

      post "/api/v1/playlists/#{playlist.id}/tracks", params: {track_id: track.id}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["added"]).to eq(0)
    end

    it "adds multiple tracks" do
      tracks = create_list(:track, 3, artist: artist, album: album, user: user)

      post "/api/v1/playlists/#{playlist.id}/tracks", params: {track_ids: tracks.map(&:id)}, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["added"]).to eq(3)
    end

    it "adds all tracks from an album" do
      create_list(:track, 4, artist: artist, album: album, user: user)

      post "/api/v1/playlists/#{playlist.id}/tracks", params: {album_id: album.id}, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["added"]).to eq(4)
    end

    it "returns error without required params" do
      post "/api/v1/playlists/#{playlist.id}/tracks", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not found for another user's playlist" do
      other_playlist = create(:playlist)
      track = create(:track, artist: artist, album: album, user: user)

      post "/api/v1/playlists/#{other_playlist.id}/tracks", params: {track_id: track.id}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/playlists/:playlist_id/tracks/:id" do
    it "removes a track from the playlist" do
      track = create(:track, artist: artist, album: album, user: user)
      pt = playlist.add_track(track)

      expect {
        delete "/api/v1/playlists/#{playlist.id}/tracks/#{pt.id}", headers: auth_headers
      }.to change(PlaylistTrack, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for invalid playlist_track id" do
      delete "/api/v1/playlists/#{playlist.id}/tracks/999999", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
