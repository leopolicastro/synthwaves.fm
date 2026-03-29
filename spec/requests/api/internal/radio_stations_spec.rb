require "rails_helper"

RSpec.describe "API::Internal::RadioStations", type: :request do
  let(:user) { create(:user) }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:station) { create(:radio_station, playlist: playlist, user: user, status: "active") }
  let(:token) { "test-liquidsoap-token" }
  let(:headers) { {"Authorization" => "Bearer #{token}"} }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LIQUIDSOAP_API_TOKEN").and_return(token)
  end

  describe "authentication" do
    it "rejects requests without a token" do
      get next_track_api_internal_radio_station_path(station)
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects requests with an invalid token" do
      get next_track_api_internal_radio_station_path(station), headers: {"Authorization" => "Bearer wrong"}
      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts requests with a valid token" do
      get next_track_api_internal_radio_station_path(station), headers: headers
      # Will be 204 (no tracks) but not 401
      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/internal/radio_stations/:id/next_track" do
    it "returns 204 when playlist is empty" do
      get next_track_api_internal_radio_station_path(station), headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it "returns 503 when station is stopped" do
      station.update!(status: "stopped")
      get next_track_api_internal_radio_station_path(station), headers: headers
      expect(response).to have_http_status(:service_unavailable)
    end

    it "returns track data with a signed URL" do
      track = create(:track, artist: artist, album: album, user: user, title: "Neon Drive")
      track.audio_file.attach(io: StringIO.new("audio"), filename: "track.mp3", content_type: "audio/mpeg")
      create(:playlist_track, playlist: playlist, track: track, position: 1)
      RadioQueueService.new(station).populate!

      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["track_id"]).to eq(track.id)
      expect(json["title"]).to eq("Neon Drive")
      expect(json["artist"]).to eq(artist.name)
      expect(json["url"]).to be_present
    end

    it "sets the current_track on the station" do
      track = create(:track, artist: artist, album: album, user: user)
      track.audio_file.attach(io: StringIO.new("audio"), filename: "track.mp3", content_type: "audio/mpeg")
      create(:playlist_track, playlist: playlist, track: track, position: 1)
      RadioQueueService.new(station).populate!

      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(station.reload.current_track).to eq(track)
    end
  end

  describe "POST /api/internal/radio_stations/:id/notify" do
    it "updates status on track_started" do
      station.update!(status: "idle")
      track = create(:track, artist: artist, album: album, user: user)

      post notify_api_internal_radio_station_path(station),
        params: {event: "track_started", track_id: track.id},
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(station.reload.status).to eq("active")
      expect(station.current_track_id).to eq(track.id)
    end

    it "updates status on error" do
      post notify_api_internal_radio_station_path(station),
        params: {event: "error", message: "Connection lost"},
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(station.reload.status).to eq("error")
      expect(station.error_message).to eq("Connection lost")
    end

    it "updates status on idle" do
      post notify_api_internal_radio_station_path(station),
        params: {event: "idle"},
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(station.reload.status).to eq("idle")
    end
  end

  describe "GET /api/internal/radio_stations/active" do
    it "returns non-stopped stations" do
      active = create(:radio_station, status: "active", user: user)
      idle = create(:radio_station, status: "idle", user: user)
      create(:radio_station, status: "stopped", user: user)

      get active_api_internal_radio_stations_path, headers: headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.pluck("id")
      expect(ids).to contain_exactly(active.id, idle.id)
    end
  end
end
