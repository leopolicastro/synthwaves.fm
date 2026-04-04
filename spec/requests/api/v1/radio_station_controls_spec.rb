require "rails_helper"

RSpec.describe "API::V1::RadioStationControls", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "POST /api/v1/radio_stations/:radio_station_id/control" do
    let(:playlist) { create(:playlist, user: user) }
    let(:station) { create(:radio_station, playlist: playlist, user: user) }

    it "starts a station" do
      post "/api/v1/radio_stations/#{station.id}/control",
        params: {action_name: "start"},
        headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("starting")
      expect(json["message"]).to eq("Station starting")
      expect(station.reload.status).to eq("starting")
      expect(StationControlJob).to have_been_enqueued.with(station.id, "start")
    end

    it "stops a station" do
      station.update!(status: "active")

      post "/api/v1/radio_stations/#{station.id}/control",
        params: {action_name: "stop"},
        headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("stopped")
      expect(station.reload.status).to eq("stopped")
      expect(StationControlJob).to have_been_enqueued.with(station.id, "stop")
    end

    it "skips a track" do
      station.update!(status: "active")

      post "/api/v1/radio_stations/#{station.id}/control",
        params: {action_name: "skip"},
        headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(StationControlJob).to have_been_enqueued.with(station.id, "skip")
    end

    it "rejects invalid action" do
      post "/api/v1/radio_stations/#{station.id}/control",
        params: {action_name: "invalid"},
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns not found for another user's station" do
      other_station = create(:radio_station)

      post "/api/v1/radio_stations/#{other_station.id}/control",
        params: {action_name: "start"},
        headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
