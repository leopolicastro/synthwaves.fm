require "rails_helper"

RSpec.describe "Subsonic Playlists API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getPlaylists.view" do
    it "returns user playlists" do
      create(:playlist, user: user, name: "My Playlist")
      get "/api/rest/getPlaylists.view", params: auth_params
      json = JSON.parse(response.body)
      playlists = json["subsonic-response"]["playlists"]["playlist"]
      expect(playlists.first["name"]).to eq("My Playlist")
    end

    it "does not return other users playlists" do
      other = create(:user)
      create(:playlist, user: other)
      get "/api/rest/getPlaylists.view", params: auth_params
      json = JSON.parse(response.body)
      playlists = json["subsonic-response"]["playlists"]["playlist"]
      expect(playlists).to be_empty
    end
  end

  describe "GET /api/rest/getPlaylist.view" do
    it "returns playlist with entries" do
      playlist = create(:playlist, user: user)
      track = create(:track)
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: playlist.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["playlist"]["entry"]).to be_present
    end

    it "returns error for nonexistent playlist" do
      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/createPlaylist.view" do
    it "creates a new playlist" do
      expect {
        get "/api/rest/createPlaylist.view", params: auth_params.merge(name: "New One")
      }.to change(Playlist, :count).by(1)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["playlist"]["name"]).to eq("New One")
    end

    it "updates an existing playlist name" do
      playlist = create(:playlist, user: user, name: "Old Name")
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: playlist.id, name: "New Name")
      expect(playlist.reload.name).to eq("New Name")
    end

    it "sets songs on playlist" do
      playlist = create(:playlist, user: user)
      track = create(:track)
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: playlist.id, songId: [track.id])
      expect(playlist.reload.tracks).to include(track)
    end

    it "returns error for another user's playlist" do
      other = create(:user)
      playlist = create(:playlist, user: other)
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: playlist.id, name: "Hijack")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/deletePlaylist.view" do
    it "deletes user's playlist" do
      playlist = create(:playlist, user: user)
      expect {
        get "/api/rest/deletePlaylist.view", params: auth_params.merge(id: playlist.id)
      }.to change(Playlist, :count).by(-1)
    end

    it "returns error for nonexistent playlist" do
      get "/api/rest/deletePlaylist.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end
end
