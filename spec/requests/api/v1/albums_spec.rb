require "rails_helper"

RSpec.describe "API::V1::Albums", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }

  describe "GET /api/v1/albums" do
    it "returns paginated albums for the current user" do
      create_list(:album, 3, artist: artist, user: user)
      create(:album) # other user's album

      get "/api/v1/albums", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["albums"].length).to eq(3)
      expect(json["pagination"]["total_count"]).to eq(3)
    end

    it "filters by artist_id" do
      other_artist = create(:artist, user: user)
      create(:album, artist: artist, user: user, title: "Target Album")
      create(:album, artist: other_artist, user: user)

      get "/api/v1/albums", params: {artist_id: artist.id}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["albums"].length).to eq(1)
      expect(json["albums"].first["title"]).to eq("Target Album")
    end

    it "searches by title" do
      create(:album, artist: artist, user: user, title: "Neon Nights")
      create(:album, artist: artist, user: user, title: "Jazz Sessions")

      get "/api/v1/albums", params: {q: "neon"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["albums"].length).to eq(1)
      expect(json["albums"].first["title"]).to eq("Neon Nights")
    end

    it "returns unauthorized without a token" do
      get "/api/v1/albums"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/albums/:id" do
    it "returns the album with tracks" do
      album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user, title: "Track 1", track_number: 1)

      get "/api/v1/albums/#{album.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq(album.title)
      expect(json["tracks"].length).to eq(1)
      expect(json["tracks"].first["title"]).to eq("Track 1")
      expect(json["total_duration"]).to be_a(Numeric)
    end

    it "returns not found for another user's album" do
      other_album = create(:album)

      get "/api/v1/albums/#{other_album.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/albums" do
    it "creates an album" do
      expect {
        post "/api/v1/albums", params: {album: {title: "New Album", artist_id: artist.id, year: 2024, genre: "synthwave"}}, headers: auth_headers
      }.to change(Album, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Album")
      expect(json["year"]).to eq(2024)
      expect(json["genre"]).to eq("synthwave")
      expect(json["artist"]["id"]).to eq(artist.id)
    end

    it "rejects duplicate title for the same artist" do
      create(:album, artist: artist, user: user, title: "Existing")

      post "/api/v1/albums", params: {album: {title: "Existing", artist_id: artist.id}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects missing title" do
      post "/api/v1/albums", params: {album: {title: "", artist_id: artist.id}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/albums/:id" do
    it "updates the album" do
      album = create(:album, artist: artist, user: user, title: "Old Title")

      patch "/api/v1/albums/#{album.id}", params: {album: {title: "New Title", year: 2025}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Title")
      expect(json["year"]).to eq(2025)
    end

    it "returns not found for another user's album" do
      other_album = create(:album)

      patch "/api/v1/albums/#{other_album.id}", params: {album: {title: "Hacked"}}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/albums/:id" do
    it "deletes the album and cascades tracks" do
      album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user)

      expect {
        delete "/api/v1/albums/#{album.id}", headers: auth_headers
      }.to change(Album, :count).by(-1)
        .and change(Track, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for another user's album" do
      other_album = create(:album)

      delete "/api/v1/albums/#{other_album.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
