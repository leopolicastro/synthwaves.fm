require "rails_helper"

RSpec.describe "API::V1::RadioStations", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/radio_stations" do
    it "returns the user's radio stations" do
      playlist = create(:playlist, user: user)
      create(:radio_station, playlist: playlist, user: user)
      create(:radio_station) # other user

      get "/api/v1/radio_stations", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["radio_stations"].length).to eq(1)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/radio_stations"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/radio_stations/:id" do
    it "returns station detail" do
      playlist = create(:playlist, user: user)
      station = create(:radio_station, playlist: playlist, user: user)

      get "/api/v1/radio_stations/#{station.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("stopped")
      expect(json["mount_point"]).to be_present
      expect(json["listen_url"]).to be_present
      expect(json["playlist"]["id"]).to eq(playlist.id)
    end

    it "returns not found for another user's station" do
      other_station = create(:radio_station)

      get "/api/v1/radio_stations/#{other_station.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/radio_stations" do
    it "creates a station from a playlist" do
      playlist = create(:playlist, user: user)

      expect {
        post "/api/v1/radio_stations", params: {playlist_id: playlist.id}, headers: auth_headers
      }.to change(RadioStation, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["playlist"]["id"]).to eq(playlist.id)
      expect(json["status"]).to eq("stopped")
    end

    it "rejects creating a second station for the same playlist" do
      playlist = create(:playlist, user: user)
      create(:radio_station, playlist: playlist, user: user)

      post "/api/v1/radio_stations", params: {playlist_id: playlist.id}, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not found for another user's playlist" do
      other_playlist = create(:playlist)

      post "/api/v1/radio_stations", params: {playlist_id: other_playlist.id}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/radio_stations/:id" do
    it "updates station settings" do
      playlist = create(:playlist, user: user)
      station = create(:radio_station, playlist: playlist, user: user, bitrate: 192)

      patch "/api/v1/radio_stations/#{station.id}",
        params: {radio_station: {bitrate: 320, playback_mode: "sequential"}},
        headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bitrate"]).to eq(320)
      expect(json["playback_mode"]).to eq("sequential")
    end

    it "rejects invalid bitrate" do
      playlist = create(:playlist, user: user)
      station = create(:radio_station, playlist: playlist, user: user)

      patch "/api/v1/radio_stations/#{station.id}",
        params: {radio_station: {bitrate: 999}},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/v1/radio_stations/:id" do
    it "deletes the station" do
      playlist = create(:playlist, user: user)
      station = create(:radio_station, playlist: playlist, user: user)

      expect {
        delete "/api/v1/radio_stations/#{station.id}", headers: auth_headers
      }.to change(RadioStation, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "enqueues stop job for active station" do
      playlist = create(:playlist, user: user)
      station = create(:radio_station, playlist: playlist, user: user, status: "active")

      delete "/api/v1/radio_stations/#{station.id}", headers: auth_headers

      expect(StationControlJob).to have_been_enqueued.with(station.id, "stop")
    end
  end
end
