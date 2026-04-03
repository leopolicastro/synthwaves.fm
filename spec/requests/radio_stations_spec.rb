require "rails_helper"

RSpec.describe "RadioStations", type: :request do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }

  before do
    login_user(user)
  end

  describe "GET /radio_stations" do
    it "returns success" do
      get radio_stations_path
      expect(response).to have_http_status(:ok)
    end

    it "lists the user's stations" do
      create(:radio_station, playlist: playlist, user: user)
      get radio_stations_path
      expect(response.body).to include(playlist.name)
    end
  end

  describe "GET /radio_stations/:id" do
    it "returns success" do
      station = create(:radio_station, playlist: playlist, user: user)
      get radio_station_path(station)
      expect(response).to have_http_status(:ok)
    end

    it "does not show another user's station" do
      other_user = create(:user)
      other_playlist = create(:playlist, user: other_user)
      station = create(:radio_station, playlist: other_playlist, user: other_user)

      get radio_station_path(station)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /radio_stations" do
    it "creates a station for a playlist" do
      expect {
        post radio_stations_path, params: {playlist_id: playlist.id}
      }.to change(RadioStation, :count).by(1)

      station = RadioStation.last
      expect(station.playlist).to eq(playlist)
      expect(station.user).to eq(user)
      expect(station.status).to eq("stopped")
      expect(response).to redirect_to(radio_station_path(station))
    end

    it "rejects creating a second station for the same playlist" do
      create(:radio_station, playlist: playlist, user: user)

      post radio_stations_path, params: {playlist_id: playlist.id}
      expect(response).to redirect_to(playlist_path(playlist))
    end
  end

  describe "PATCH /radio_stations/:id" do
    it "updates station settings" do
      station = create(:radio_station, playlist: playlist, user: user)

      patch radio_station_path(station), params: {radio_station: {
        playback_mode: "sequential",
        bitrate: 320,
        crossfade: false
      }}

      station.reload
      expect(station.playback_mode).to eq("sequential")
      expect(station.bitrate).to eq(320)
      expect(station.crossfade).to be false
      expect(response).to redirect_to(radio_station_path(station))
    end

    it "attaches a station image" do
      station = create(:radio_station, playlist: playlist, user: user)
      image = fixture_file_upload("test.png", "image/png")

      patch radio_station_path(station), params: {radio_station: {image: image}}

      station.reload
      expect(station.image).to be_attached
      expect(response).to redirect_to(radio_station_path(station))
    end
  end

  describe "POST /radio_stations/:id/start" do
    it "sets status to starting and enqueues job" do
      station = create(:radio_station, playlist: playlist, user: user)

      expect {
        post start_radio_station_path(station)
      }.to have_enqueued_job(StationControlJob).with(station.id, "start")

      expect(station.reload.status).to eq("starting")
      expect(response).to redirect_to(radio_station_path(station))
    end

    it "populates the queue" do
      track = create(:track, user: user)
      track.audio_file.attach(io: StringIO.new("audio"), filename: "track.mp3", content_type: "audio/mpeg")
      create(:playlist_track, playlist: playlist, track: track, position: 1)
      station = create(:radio_station, playlist: playlist, user: user)

      post start_radio_station_path(station)

      expect(station.radio_queue_tracks.upcoming.count).to eq(1)
    end
  end

  describe "POST /radio_stations/:id/stop" do
    it "sets status to stopped and enqueues job" do
      station = create(:radio_station, playlist: playlist, user: user, status: "active")

      expect {
        post stop_radio_station_path(station)
      }.to have_enqueued_job(StationControlJob).with(station.id, "stop")

      expect(station.reload.status).to eq("stopped")
      expect(response).to redirect_to(radio_station_path(station))
    end

    it "clears the queue" do
      station = create(:radio_station, playlist: playlist, user: user, status: "active")
      create(:radio_queue_track, radio_station: station, track: create(:track), position: 1)

      post stop_radio_station_path(station)

      expect(station.radio_queue_tracks.count).to eq(0)
    end
  end

  describe "POST /radio_stations/:id/skip" do
    it "enqueues a skip job" do
      station = create(:radio_station, playlist: playlist, user: user, status: "active")

      expect {
        post skip_radio_station_path(station)
      }.to have_enqueued_job(StationControlJob).with(station.id, "skip")

      expect(response).to redirect_to(radio_station_path(station))
    end
  end

  describe "DELETE /radio_stations/:id" do
    it "destroys the station" do
      station = create(:radio_station, playlist: playlist, user: user)

      expect {
        delete radio_station_path(station)
      }.to change(RadioStation, :count).by(-1)

      expect(response).to redirect_to(radio_stations_path)
    end
  end
end
