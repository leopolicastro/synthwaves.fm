require "rails_helper"

RSpec.describe "API::V1::Stats", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/stats" do
    it "returns library and listening stats" do
      get "/api/v1/stats", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["library"]).to include(
        "track_count", "album_count", "artist_count",
        "total_duration", "total_file_size", "avg_track_duration", "top_genres"
      )

      expect(json["listening"]).to include(
        "time_range", "total_plays", "total_listening_time",
        "current_streak", "longest_streak",
        "top_tracks", "top_artists", "top_genres",
        "hourly_distribution", "daily_distribution"
      )
    end

    it "accepts time_range parameter" do
      get "/api/v1/stats", params: {time_range: "week"}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["listening"]["time_range"]).to eq("week")
    end

    it "rejects invalid time_range" do
      get "/api/v1/stats", params: {time_range: "invalid"}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "includes play data when present" do
      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user, genre: "synthwave")
      track = create(:track, artist: artist, album: album, user: user)
      create(:play_history, user: user, track: track, played_at: 1.hour.ago)

      get "/api/v1/stats", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["library"]["track_count"]).to eq(1)
      expect(json["listening"]["total_plays"]).to eq(1)
      expect(json["listening"]["top_tracks"].length).to eq(1)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/stats"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
