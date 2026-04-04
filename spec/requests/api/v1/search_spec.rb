require "rails_helper"

RSpec.describe "API::V1::Search", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/search" do
    it "searches across artists, albums, and tracks" do
      artist = create(:artist, name: "Neon Rider", user: user)
      album = create(:album, title: "Neon Nights", artist: artist, user: user)
      create(:track, title: "Neon Drive", artist: artist, album: album, user: user)

      get "/api/v1/search", params: {q: "neon"}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["artists"].length).to eq(1)
      expect(json["albums"].length).to eq(1)
      expect(json["tracks"].length).to eq(1)
    end

    it "filters by type" do
      create(:artist, name: "Neon Rider", user: user)

      get "/api/v1/search", params: {q: "neon", types: "artist"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["artists"].length).to eq(1)
      expect(json["albums"]).to be_empty
      expect(json["tracks"]).to be_empty
    end

    it "requires q parameter" do
      get "/api/v1/search", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "scopes results to the current user" do
      create(:artist, name: "Neon Rider", user: user)
      create(:artist, name: "Neon Other") # other user

      get "/api/v1/search", params: {q: "neon"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["artists"].length).to eq(1)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/search", params: {q: "test"}
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
