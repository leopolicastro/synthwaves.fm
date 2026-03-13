require "rails_helper"

RSpec.describe "API Import Playlists", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({ user_id: user.id, api_key_id: api_key.id }) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  let(:artist) { create(:artist, name: "The Beatles", user: user) }
  let(:album) { create(:album, title: "Abbey Road", artist: artist, user: user) }

  describe "POST /api/import/playlists" do
    it "creates a playlist with matched tracks in sequential positions" do
      track1 = create(:track, title: "Come Together", artist: artist, album: album)
      track2 = create(:track, title: "Something", artist: artist, album: album)

      post api_import_playlists_path, params: {
        name: "Beatles Favorites",
        tracks: [
          { title: "Come Together", artist: "The Beatles", album: "Abbey Road" },
          { title: "Something", artist: "The Beatles", album: "Abbey Road" }
        ]
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Beatles Favorites")
      expect(json["tracks_matched"]).to eq(2)
      expect(json["tracks_not_found"]).to eq(0)
      expect(json["not_found"]).to be_empty

      playlist = Playlist.find(json["id"])
      expect(playlist.playlist_tracks.map(&:position)).to eq([1, 2])
      expect(playlist.tracks).to eq([track1, track2])
    end

    it "reports unmatched tracks without failing" do
      create(:track, title: "Come Together", artist: artist, album: album)

      post api_import_playlists_path, params: {
        name: "Mixed",
        tracks: [
          { title: "Come Together", artist: "The Beatles", album: "Abbey Road" },
          { title: "Nonexistent Song", artist: "Nobody", album: "Nothing" }
        ]
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tracks_matched"]).to eq(1)
      expect(json["tracks_not_found"]).to eq(1)
      expect(json["not_found"]).to contain_exactly(
        { "title" => "Nonexistent Song", "artist" => "Nobody", "album" => "Nothing" }
      )
    end

    it "returns 409 for duplicate playlist name" do
      create(:playlist, name: "Existing", user: user)

      post api_import_playlists_path, params: {
        name: "Existing",
        tracks: []
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json["error"]).to match(/already exists/)
    end

    it "returns 422 when name is missing" do
      post api_import_playlists_path, params: {
        tracks: []
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without auth" do
      post api_import_playlists_path, params: {
        name: "Test", tracks: []
      }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "matches tracks case-insensitively" do
      create(:track, title: "Come Together", artist: artist, album: album)

      post api_import_playlists_path, params: {
        name: "Case Test",
        tracks: [
          { title: "come together", artist: "the beatles", album: "abbey road" }
        ]
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tracks_matched"]).to eq(1)
    end

    it "creates an empty playlist when tracks array is empty" do
      post api_import_playlists_path, params: {
        name: "Empty Playlist",
        tracks: []
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tracks_matched"]).to eq(0)
      expect(Playlist.find(json["id"]).tracks).to be_empty
    end

    it "assigns sequential positions with no gaps when some tracks are unmatched" do
      track1 = create(:track, title: "Come Together", artist: artist, album: album)
      track2 = create(:track, title: "Something", artist: artist, album: album)

      post api_import_playlists_path, params: {
        name: "Gapped",
        tracks: [
          { title: "Come Together", artist: "The Beatles", album: "Abbey Road" },
          { title: "Missing Track", artist: "Nobody", album: "Nothing" },
          { title: "Something", artist: "The Beatles", album: "Abbey Road" }
        ]
      }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      playlist = Playlist.find(JSON.parse(response.body)["id"])
      expect(playlist.playlist_tracks.order(:position).map(&:position)).to eq([1, 2])
      expect(playlist.tracks.order("playlist_tracks.position")).to eq([track1, track2])
    end
  end
end
