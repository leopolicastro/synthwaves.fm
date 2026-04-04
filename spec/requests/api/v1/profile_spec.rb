require "rails_helper"

RSpec.describe "API::V1::Profile", type: :request do
  let(:user) { create(:user, name: "Leo", theme: "synthwave") }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/me" do
    it "returns the current user profile" do
      get "/api/v1/me", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Leo")
      expect(json["email_address"]).to eq(user.email_address)
      expect(json["theme"]).to eq("synthwave")
      expect(json["stats"]).to include(
        "artists_count" => 0,
        "albums_count" => 0,
        "tracks_count" => 0,
        "playlists_count" => 0
      )
    end

    it "includes accurate library stats" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user)
      create(:track, artist: artist, album: album, user: user)
      create(:playlist, user: user)

      get "/api/v1/me", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["stats"]).to include(
        "artists_count" => 1,
        "albums_count" => 1,
        "tracks_count" => 1,
        "playlists_count" => 1
      )
    end

    it "returns unauthorized without a token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/me" do
    it "updates the user name" do
      patch "/api/v1/me", params: {name: "New Name"}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New Name")
      expect(user.reload.name).to eq("New Name")
    end

    it "updates the user theme" do
      patch "/api/v1/me", params: {theme: "jazz"}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["theme"]).to eq("jazz")
    end

    it "rejects an invalid theme" do
      patch "/api/v1/me", params: {theme: "invalid"}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include(/Theme/)
    end

    it "returns unauthorized without a token" do
      patch "/api/v1/me", params: {name: "Hacker"}

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
