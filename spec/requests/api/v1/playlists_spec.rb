require "rails_helper"

RSpec.describe "API::V1::Playlists", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/playlists" do
    it "returns paginated playlists for the current user" do
      create_list(:playlist, 3, user: user)
      create(:playlist) # other user

      get "/api/v1/playlists", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["playlists"].length).to eq(3)
      expect(json["pagination"]["total_count"]).to eq(3)
    end

    it "searches by name" do
      create(:playlist, name: "Chill Vibes", user: user)
      create(:playlist, name: "Workout Mix", user: user)

      get "/api/v1/playlists", params: {q: "chill"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["playlists"].length).to eq(1)
      expect(json["playlists"].first["name"]).to eq("Chill Vibes")
    end

    it "returns unauthorized without a token" do
      get "/api/v1/playlists"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/playlists/:id" do
    it "returns the playlist with tracks" do
      playlist = create(:playlist, user: user)
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user)
      track = create(:track, artist: artist, album: album, user: user)
      playlist.add_track(track)

      get "/api/v1/playlists/#{playlist.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq(playlist.name)
      expect(json["tracks"].length).to eq(1)
      expect(json["tracks"].first["position"]).to eq(1)
      expect(json["tracks"].first["track"]["title"]).to eq(track.title)
      expect(json["total_duration"]).to be_a(Numeric)
    end

    it "returns not found for another user's playlist" do
      other_playlist = create(:playlist)

      get "/api/v1/playlists/#{other_playlist.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/playlists" do
    it "creates a playlist" do
      expect {
        post "/api/v1/playlists", params: {playlist: {name: "New Playlist"}}, headers: auth_headers
      }.to change(Playlist, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New Playlist")
    end

    it "creates a playlist with initial tracks" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user)
      tracks = create_list(:track, 3, artist: artist, album: album, user: user)

      post "/api/v1/playlists", params: {
        playlist: {name: "With Tracks"},
        track_ids: tracks.map(&:id)
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      playlist = Playlist.last
      expect(playlist.playlist_tracks.count).to eq(3)
    end

    it "rejects missing name" do
      post "/api/v1/playlists", params: {playlist: {name: ""}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/playlists/:id" do
    it "updates the playlist name" do
      playlist = create(:playlist, name: "Old", user: user)

      patch "/api/v1/playlists/#{playlist.id}", params: {playlist: {name: "New"}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New")
    end
  end

  describe "DELETE /api/v1/playlists/:id" do
    it "deletes the playlist" do
      playlist = create(:playlist, user: user)

      expect {
        delete "/api/v1/playlists/#{playlist.id}", headers: auth_headers
      }.to change(Playlist, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
