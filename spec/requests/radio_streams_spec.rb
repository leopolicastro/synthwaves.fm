require "rails_helper"

RSpec.describe "RadioStreams", type: :request do
  let(:user) { create(:user) }

  before do
    login_user(user)
    Flipper.enable(:youtube_radio)
  end

  describe "GET /radio_stations/:id/stream" do
    it "returns 404 for youtube-type stations" do
      station = create(:radio_station, user: user, source_type: "youtube")

      get radio_station_stream_path(station)

      expect(response).to have_http_status(:not_found)
    end

    it "proxies the audio stream for stream-type stations" do
      station = create(:radio_station, :stream, user: user, stream_url: "https://radio.example.com/stream")

      stub_request(:get, "https://radio.example.com/stream")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/mpeg"},
          body: "fake audio data"
        )

      get radio_station_stream_path(station)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("audio/mpeg")
      expect(response.headers["X-Accel-Buffering"]).to eq("no")
      expect(response.body).to eq("fake audio data")
    end

    it "returns 502 when upstream stream fails" do
      station = create(:radio_station, :stream, user: user, stream_url: "https://radio.example.com/broken")

      stub_request(:get, "https://radio.example.com/broken")
        .to_raise(HTTP::ConnectionError.new("Connection refused"))

      get radio_station_stream_path(station)

      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
