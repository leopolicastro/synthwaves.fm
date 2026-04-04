require "rails_helper"

RSpec.describe "API::V1::TrackMetadata", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/track_metadata" do
    it "returns available genres, languages, and decades" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user, genre: "synthwave")
      create(:track, artist: artist, album: album, user: user, language: "en", release_year: 1985)

      tag = Tag.find_or_create_by!(name: "synthwave", tag_type: "genre")
      user.taggings.create!(tag: tag, taggable: Track.last)

      get "/api/v1/track_metadata", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("genres")
      expect(json).to have_key("languages")
      expect(json).to have_key("decades")
    end

    it "returns empty arrays when no data" do
      get "/api/v1/track_metadata", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["genres"]).to eq([])
      expect(json["languages"]).to eq([])
      expect(json["decades"]).to eq([])
    end

    it "returns unauthorized without a token" do
      get "/api/v1/track_metadata"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
