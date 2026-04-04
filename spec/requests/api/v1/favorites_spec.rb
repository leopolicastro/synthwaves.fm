require "rails_helper"

RSpec.describe "API::V1::Favorites", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }

  describe "GET /api/v1/favorites" do
    it "returns all favorites" do
      track = create(:track, artist: artist, album: album, user: user)
      create(:favorite, user: user, favorable: track)
      create(:favorite, user: user, favorable: artist)

      get "/api/v1/favorites", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["favorites"].length).to eq(2)
    end

    it "filters by type" do
      track = create(:track, artist: artist, album: album, user: user)
      create(:favorite, user: user, favorable: track)
      create(:favorite, user: user, favorable: artist)

      get "/api/v1/favorites", params: {type: "Track"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["favorites"].length).to eq(1)
      expect(json["favorites"].first["favorable_type"]).to eq("Track")
    end

    it "returns unauthorized without a token" do
      get "/api/v1/favorites"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/favorites" do
    it "creates a favorite" do
      track = create(:track, artist: artist, album: album, user: user)

      expect {
        post "/api/v1/favorites", params: {favorable_type: "Track", favorable_id: track.id}, headers: auth_headers
      }.to change(Favorite, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["favorable_type"]).to eq("Track")
    end

    it "is idempotent for existing favorites" do
      track = create(:track, artist: artist, album: album, user: user)
      create(:favorite, user: user, favorable: track)

      expect {
        post "/api/v1/favorites", params: {favorable_type: "Track", favorable_id: track.id}, headers: auth_headers
      }.not_to change(Favorite, :count)

      expect(response).to have_http_status(:ok)
    end

    it "rejects invalid favorable_type" do
      post "/api/v1/favorites", params: {favorable_type: "Invalid", favorable_id: 1}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not found for non-existent resource" do
      post "/api/v1/favorites", params: {favorable_type: "Track", favorable_id: 999999}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/favorites/:id" do
    it "deletes a favorite by id" do
      track = create(:track, artist: artist, album: album, user: user)
      favorite = create(:favorite, user: user, favorable: track)

      expect {
        delete "/api/v1/favorites/#{favorite.id}", headers: auth_headers
      }.to change(Favorite, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for invalid id" do
      delete "/api/v1/favorites/999999", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
