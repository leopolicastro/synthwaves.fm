require "rails_helper"

RSpec.describe "Subsonic Radio API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getInternetRadioStations.view" do
    before { Flipper.enable(:radio_stations) }

    it "returns active playlist radio stations" do
      playlist = create(:playlist, name: "Chill Vibes", user: user)
      create(:radio_station, playlist: playlist, user: user, status: "active", mount_point: "/chill-vibes.mp3")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations.size).to eq(1)
      expect(stations.first["name"]).to eq("Chill Vibes")
      expect(stations.first["streamUrl"]).to include("/chill-vibes.mp3")
      expect(stations.first["id"]).to eq("radio-#{RadioStation.last.id}")
    end

    it "excludes stopped radio stations" do
      playlist = create(:playlist, user: user)
      create(:radio_station, playlist: playlist, user: user, status: "stopped")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations).to be_empty
    end

    it "returns stream-type external streams" do
      create(:external_stream, :stream, user: user, name: "Jazz FM", stream_url: "https://jazz.example.com/stream")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations.size).to eq(1)
      expect(stations.first["name"]).to eq("Jazz FM")
      expect(stations.first["streamUrl"]).to eq("https://jazz.example.com/stream")
    end

    it "excludes youtube-type external streams" do
      create(:external_stream, user: user, source_type: "youtube")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations).to be_empty
    end

    it "returns both radio stations and external streams" do
      playlist = create(:playlist, name: "My Station", user: user)
      create(:radio_station, playlist: playlist, user: user, status: "active")
      create(:external_stream, :stream, user: user, name: "External Radio")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations.size).to eq(2)
      names = stations.pluck("name")
      expect(names).to contain_exactly("My Station", "External Radio")
    end

    it "excludes radio stations when feature flag is disabled" do
      Flipper.disable(:radio_stations)
      playlist = create(:playlist, name: "Gated Station", user: user)
      create(:radio_station, playlist: playlist, user: user, status: "active")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations).to be_empty
    end

    it "does not return another user's stations" do
      other_user = create(:user)
      other_playlist = create(:playlist, user: other_user)
      create(:radio_station, playlist: other_playlist, user: other_user, status: "active")
      create(:external_stream, :stream, user: other_user, name: "Other Radio")

      get "/api/rest/getInternetRadioStations.view", params: auth_params

      body = response.parsed_body
      stations = body.dig("subsonic-response", "internetRadioStations", "internetRadioStation")
      expect(stations).to be_empty
    end
  end
end
