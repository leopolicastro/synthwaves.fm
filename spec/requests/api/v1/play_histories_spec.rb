require "rails_helper"

RSpec.describe "API::V1::PlayHistories", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }

  describe "GET /api/v1/play_histories" do
    it "returns play history ordered by most recent" do
      track = create(:track, artist: artist, album: album, user: user)
      create(:play_history, user: user, track: track, played_at: 2.hours.ago)
      create(:play_history, user: user, track: track, played_at: 1.hour.ago)

      get "/api/v1/play_histories", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["play_histories"].length).to eq(2)
      # Most recent first
      expect(json["play_histories"].first["played_at"]).to be > json["play_histories"].last["played_at"]
    end

    it "returns unauthorized without a token" do
      get "/api/v1/play_histories"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/play_histories" do
    it "records a play event" do
      track = create(:track, artist: artist, album: album, user: user)

      expect {
        post "/api/v1/play_histories", params: {track_id: track.id}, headers: auth_headers
      }.to change(PlayHistory, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["track"]["id"]).to eq(track.id)
      expect(json["played_at"]).to be_present
    end

    it "returns not found for non-existent track" do
      post "/api/v1/play_histories", params: {track_id: 999999}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
