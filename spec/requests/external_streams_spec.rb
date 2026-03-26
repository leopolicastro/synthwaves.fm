require "rails_helper"

RSpec.describe "ExternalStreams", type: :request do
  let(:user) { create(:user) }

  before do
    login_user(user)
    Flipper.enable(:youtube_radio)
  end

  describe "GET /external_streams" do
    it "returns success" do
      get external_streams_path
      expect(response).to have_http_status(:ok)
    end

    it "displays external streams" do
      create(:external_stream, user: user, name: "Lo-Fi Beats")
      get external_streams_path
      expect(response.body).to include("Lo-Fi Beats")
    end
  end

  describe "GET /external_streams/new" do
    it "returns success" do
      get new_external_stream_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /external_streams" do
    context "youtube source type" do
      it "creates an external stream with valid YouTube URL" do
        stub_request(:get, %r{youtube\.com/oembed})
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {title: "Lo-Fi Beats", thumbnail_url: "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg"}.to_json
          )

        expect {
          post external_streams_path, params: {external_stream: {
            source_type: "youtube",
            youtube_url: "https://www.youtube.com/watch?v=jfKfPfyJRdk"
          }}
        }.to change(ExternalStream, :count).by(1)

        station = ExternalStream.last
        expect(station.source_type).to eq("youtube")
        expect(station.youtube_video_id).to eq("jfKfPfyJRdk")
        expect(station.name).to eq("Lo-Fi Beats")
        expect(response).to redirect_to(external_streams_path)
      end

      it "creates an external stream with manual name and still fetches thumbnail" do
        stub_request(:get, %r{youtube\.com/oembed})
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {title: "Lo-Fi Beats", thumbnail_url: "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg"}.to_json
          )

        expect {
          post external_streams_path, params: {external_stream: {
            source_type: "youtube",
            youtube_url: "https://www.youtube.com/watch?v=jfKfPfyJRdk",
            name: "My Radio"
          }}
        }.to change(ExternalStream, :count).by(1)

        station = ExternalStream.last
        expect(station.name).to eq("My Radio")
        expect(station.thumbnail_url).to eq("https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg")
      end

      it "rejects invalid URL" do
        post external_streams_path, params: {external_stream: {
          source_type: "youtube",
          youtube_url: "https://example.com/not-youtube",
          name: "Bad Station"
        }}
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "stream source type" do
      it "creates a stream station with a direct URL" do
        stub_request(:get, "https://radio.example.com/stream")
          .to_return(
            status: 200,
            headers: {"Content-Type" => "audio/mpeg"},
            body: "fake audio data"
          )

        expect {
          post external_streams_path, params: {external_stream: {
            source_type: "stream",
            stream_url: "https://radio.example.com/stream",
            name: "My Stream"
          }}
        }.to change(ExternalStream, :count).by(1)

        station = ExternalStream.last
        expect(station.source_type).to eq("stream")
        expect(station.stream_url).to eq("https://radio.example.com/stream")
        expect(station.name).to eq("My Stream")
        expect(response).to redirect_to(external_streams_path)
      end

      it "creates a stream station from a .pls URL and resolves it" do
        pls_body = <<~PLS
          [playlist]
          NumberOfEntries=1
          File1=https://radio.example.com/actual-stream
          Title1=Cool Radio
        PLS

        stub_request(:get, "https://example.com/station.pls")
          .to_return(
            status: 200,
            headers: {"Content-Type" => "audio/x-scpls"},
            body: pls_body
          )

        stub_request(:head, "https://radio.example.com/actual-stream")
          .to_return(status: 200)

        expect {
          post external_streams_path, params: {external_stream: {
            source_type: "stream",
            stream_url: "https://example.com/station.pls"
          }}
        }.to change(ExternalStream, :count).by(1)

        station = ExternalStream.last
        expect(station.stream_url).to eq("https://radio.example.com/actual-stream")
        expect(station.original_url).to eq("https://example.com/station.pls")
        expect(station.name).to eq("Cool Radio")
      end

      it "rejects a stream with a resolver error" do
        stub_request(:get, "https://example.com/broken")
          .to_raise(HTTP::ConnectionError.new("Connection refused"))

        post external_streams_path, params: {external_stream: {
          source_type: "stream",
          stream_url: "https://example.com/broken",
          name: "Broken Stream"
        }}

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects a stream station without a stream_url" do
        post external_streams_path, params: {external_stream: {
          source_type: "stream",
          name: "No URL"
        }}

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /external_streams/:id" do
    it "deletes the user's own station" do
      station = create(:external_stream, user: user)

      expect {
        delete external_stream_path(station)
      }.to change(ExternalStream, :count).by(-1)

      expect(response).to redirect_to(external_streams_path)
    end

    it "does not delete another user's station" do
      other_user = create(:user)
      station = create(:external_stream, user: other_user)

      expect {
        delete external_stream_path(station)
      }.not_to change(ExternalStream, :count)
    end
  end
end
