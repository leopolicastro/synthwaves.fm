require "rails_helper"

RSpec.describe "Webhooks::SongDownloads", type: :request do
  let(:user) { create(:user) }
  let(:song_download) { create(:song_download, user: user, status: "processing", total_tracks: 1) }

  describe "POST /webhooks/song_download/:token" do
    context "with valid token and multipart success" do
      it "creates a track from the uploaded file" do
        allow(ItunesSearch).to receive(:call).and_return(nil)

        file = fixture_file_upload("test.mp3", "audio/mpeg")

        expect {
          post webhooks_song_download_path(token: song_download.webhook_token),
            params: {
              file: file,
              metadata: {"artist" => "Test Artist", "title" => "Test Song", "duration" => 180.0}.to_json
            }
        }.to change(Track, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(song_download.reload.tracks_received).to eq(1)
        expect(song_download.status).to eq("completed")
      end
    end

    context "with valid token and JSON failure" do
      it "increments tracks_failed" do
        post webhooks_song_download_path(token: song_download.webhook_token),
          params: {track_number: 1, error: "Download failed"}.to_json,
          headers: {"Content-Type" => "application/json"}

        expect(response).to have_http_status(:ok)
        expect(song_download.reload.tracks_failed).to eq(1)
        expect(song_download.status).to eq("failed")
      end
    end

    context "with invalid token" do
      it "returns 404" do
        post webhooks_song_download_path(token: "invalid-token")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
