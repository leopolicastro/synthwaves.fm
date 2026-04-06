require "rails_helper"

RSpec.describe "API::V1::PublicRadioStations", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/radio" do
    it "returns unauthorized without authentication" do
      create(:radio_station, status: "active")

      get "/api/v1/radio"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns active stations" do
      create(:radio_station, status: "active")
      create(:radio_station, status: "idle")

      get "/api/v1/radio", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["radio_stations"].length).to eq(2)
    end

    it "excludes stopped stations" do
      create(:radio_station, status: "active")
      create(:radio_station, status: "stopped")

      get "/api/v1/radio", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["radio_stations"].length).to eq(1)
    end

    it "orders by listener count descending" do
      create(:radio_station, status: "active", listener_count: 5)
      create(:radio_station, status: "active", listener_count: 20)

      get "/api/v1/radio", headers: auth_headers

      json = JSON.parse(response.body)
      counts = json["radio_stations"].map { |s| s["listener_count"] }
      expect(counts).to eq([20, 5])
    end

    it "includes listen_url, listener_count, and slug" do
      station = create(:radio_station, status: "active")

      get "/api/v1/radio", headers: auth_headers

      json = JSON.parse(response.body)
      entry = json["radio_stations"].first
      expect(entry["listen_url"]).to eq(station.listen_url)
      expect(entry["listener_count"]).to eq(station.listener_count)
      expect(entry["slug"]).to eq(station.slug)
    end

    it "does not expose private configuration fields" do
      create(:radio_station, status: "active")

      get "/api/v1/radio", headers: auth_headers

      json = JSON.parse(response.body)
      entry = json["radio_stations"].first
      expect(entry).not_to have_key("playback_mode")
      expect(entry).not_to have_key("crossfade_duration")
      expect(entry).not_to have_key("bitrate")
      expect(entry).not_to have_key("playlist")
    end
  end

  describe "GET /api/v1/radio/:slug" do
    it "returns unauthorized without authentication" do
      create(:radio_station, status: "active", mount_point: "/chill-vibes.mp3")

      get "/api/v1/radio/chill-vibes"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns station detail by slug" do
      station = create(:radio_station, status: "active", mount_point: "/chill-vibes.mp3")

      get "/api/v1/radio/chill-vibes", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["slug"]).to eq("chill-vibes")
      expect(json["listen_url"]).to eq(station.listen_url)
    end

    it "includes current track when present" do
      track = create(:track)
      station = create(:radio_station, status: "active", current_track: track)

      get "/api/v1/radio/#{station.slug}", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["current_track"]["id"]).to eq(track.id)
      expect(json["current_track"]["title"]).to eq(track.title)
    end

    it "returns null current_track when no track is playing" do
      station = create(:radio_station, status: "active")

      get "/api/v1/radio/#{station.slug}", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["current_track"]).to be_nil
    end

    it "includes image_url when station has an image" do
      station = create(:radio_station, status: "active")
      station.image.attach(io: StringIO.new("fake"), filename: "logo.png", content_type: "image/png")

      get "/api/v1/radio/#{station.slug}", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["image_url"]).to be_present
    end

    it "returns null image_url when no image attached" do
      station = create(:radio_station, status: "active")

      get "/api/v1/radio/#{station.slug}", headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["image_url"]).to be_nil
    end

    it "returns not found for unknown slug" do
      get "/api/v1/radio/nonexistent", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
