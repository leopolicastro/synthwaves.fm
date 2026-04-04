require "rails_helper"

RSpec.describe "API::V1::Artists", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/artists" do
    it "returns paginated artists for the current user" do
      create_list(:artist, 3, user: user)
      create(:artist) # other user's artist

      get "/api/v1/artists", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["artists"].length).to eq(3)
      expect(json["pagination"]["total_count"]).to eq(3)
    end

    it "searches by name" do
      create(:artist, name: "Synthwave Dreams", user: user)
      create(:artist, name: "Jazz Cafe", user: user)

      get "/api/v1/artists", params: {q: "synth"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["artists"].length).to eq(1)
      expect(json["artists"].first["name"]).to eq("Synthwave Dreams")
    end

    it "filters by category" do
      create(:artist, user: user, category: "music")
      create(:artist, :podcast, user: user)

      get "/api/v1/artists", params: {category: "podcast"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["artists"].length).to eq(1)
      expect(json["artists"].first["category"]).to eq("podcast")
    end

    it "sorts by name" do
      create(:artist, name: "Bravo", user: user)
      create(:artist, name: "Alpha", user: user)

      get "/api/v1/artists", params: {sort: "name", direction: "asc"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["artists"].map { |a| a["name"] }).to eq(["Alpha", "Bravo"])
    end

    it "returns unauthorized without a token" do
      get "/api/v1/artists"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/artists/:id" do
    it "returns the artist with albums" do
      artist = create(:artist, user: user)
      create(:album, artist: artist, user: user, title: "First Album")

      get "/api/v1/artists/#{artist.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq(artist.name)
      expect(json["albums"].length).to eq(1)
      expect(json["albums"].first["title"]).to eq("First Album")
    end

    it "returns not found for another user's artist" do
      other_artist = create(:artist)

      get "/api/v1/artists/#{other_artist.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/artists" do
    it "creates an artist" do
      expect {
        post "/api/v1/artists", params: {artist: {name: "New Artist"}}, headers: auth_headers
      }.to change(Artist, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New Artist")
      expect(json["category"]).to eq("music")
    end

    it "creates a podcast artist" do
      post "/api/v1/artists", params: {artist: {name: "My Podcast", category: "podcast"}}, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["category"]).to eq("podcast")
    end

    it "rejects duplicate names for the same user" do
      create(:artist, name: "Existing", user: user)

      post "/api/v1/artists", params: {artist: {name: "Existing"}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include(/Name/)
    end

    it "rejects missing name" do
      post "/api/v1/artists", params: {artist: {name: ""}}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/artists/:id" do
    it "updates the artist" do
      artist = create(:artist, name: "Old Name", user: user)

      patch "/api/v1/artists/#{artist.id}", params: {artist: {name: "New Name"}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New Name")
      expect(artist.reload.name).to eq("New Name")
    end

    it "returns not found for another user's artist" do
      other_artist = create(:artist)

      patch "/api/v1/artists/#{other_artist.id}", params: {artist: {name: "Hacked"}}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/artists/:id" do
    it "deletes the artist and cascades" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user)

      expect {
        delete "/api/v1/artists/#{artist.id}", headers: auth_headers
      }.to change(Artist, :count).by(-1)
        .and change(Album, :count).by(-1)
        .and change(Track, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for another user's artist" do
      other_artist = create(:artist)

      delete "/api/v1/artists/#{other_artist.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
