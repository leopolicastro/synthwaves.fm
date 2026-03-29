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
      stub_icecast_listeners(station.mount_point => 1)
      get next_track_api_internal_radio_station_path(station), headers: headers
      # Will be 204 (no tracks) but not 401
      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/internal/radio_stations/:id/next_track" do
    before { stub_icecast_listeners(station.mount_point => 1) }

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

      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["track_id"]).to eq(track.id)
      expect(json["title"]).to eq("Neon Drive")
      expect(json["artist"]).to eq(artist.name)
      expect(json["url"]).to be_present
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

  describe "GET /api/internal/radio_stations/:id/next_track (idle - no listeners)" do
    let(:track1) { create(:track, artist: artist, album: album, user: user, title: "Track 1", duration: 180) }
    let(:track2) { create(:track, artist: artist, album: album, user: user, title: "Track 2", duration: 200) }

    before do
      track1.audio_file.attach(io: StringIO.new("audio"), filename: "t1.mp3", content_type: "audio/mpeg")
      track2.audio_file.attach(io: StringIO.new("audio"), filename: "t2.mp3", content_type: "audio/mpeg")
      create(:playlist_track, playlist: playlist, track: track1, position: 1)
      create(:playlist_track, playlist: playlist, track: track2, position: 2)
      stub_icecast_listeners(station.mount_point => 0)
    end

    it "returns 204 when no listeners" do
      get next_track_api_internal_radio_station_path(station), headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it "does not generate a signed S3 URL when no listeners" do
      allow(NextTrackService).to receive(:call).and_call_original

      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(NextTrackService).not_to have_received(:call)
    end

    it "advances the current track when duration has elapsed" do
      station.update!(current_track: track1, queued_track: track1, last_track_at: 200.seconds.ago)

      get next_track_api_internal_radio_station_path(station), headers: headers

      station.reload
      expect(station.current_track).not_to eq(track1)
      expect(station.last_track_at).to be_within(2.seconds).of(Time.current)
    end

    it "does not advance the current track before duration elapses" do
      station.update!(current_track: track1, queued_track: track1, last_track_at: 10.seconds.ago)

      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(station.reload.current_track).to eq(track1)
    end

    it "broadcasts now_playing when advancing tracks" do
      station.update!(current_track: track1, queued_track: track1, last_track_at: 200.seconds.ago)
      allow(station).to receive(:broadcast_now_playing)
      allow(RadioStation).to receive(:find).and_return(station)

      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(station).to have_received(:broadcast_now_playing)
    end

    it "uses default duration when track duration is nil" do
      track1.update_column(:duration, nil)
      station.update!(current_track: track1, queued_track: track1, last_track_at: 250.seconds.ago)

      # 250s < 240s default — should advance
      get next_track_api_internal_radio_station_path(station), headers: headers

      expect(station.reload.current_track).not_to eq(track1)
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

  def stub_icecast_listeners(mount_listeners)
    sources = mount_listeners.map do |mount, count|
      {"listenurl" => "http://localhost:8000#{mount}", "listeners" => count}
    end
    body = {"icestats" => {"source" => sources.length == 1 ? sources.first : sources}}
    stub_request(:get, %r{status-json\.xsl})
      .to_return(status: 200, body: body.to_json, headers: {"Content-Type" => "application/json"})
  end
end
