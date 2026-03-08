require "rails_helper"

RSpec.describe "API Import Tracks", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({ user_id: user.id, api_key_id: api_key.id }) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/import/tracks" do
    it "creates a track from an uploaded audio file" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      expect {
        post api_import_tracks_path, params: { audio_file: file }, headers: auth_headers
      }.to change(Track, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Test Song")
      expect(json["artist"]).to eq("Test Artist")
      expect(json["album"]).to eq("Test Album")
      expect(json["created"]).to be true
    end

    it "returns existing track without creating a duplicate" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post api_import_tracks_path, params: { audio_file: file }, headers: auth_headers
      expect(response).to have_http_status(:created)

      expect {
        file = fixture_file_upload("test.mp3", "audio/mpeg")
        post api_import_tracks_path, params: { audio_file: file }, headers: auth_headers
      }.not_to change(Track, :count)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["created"]).to be false
    end

    it "returns unprocessable_entity without a file" do
      post api_import_tracks_path, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("audio_file is required")
    end

    it "returns unauthorized without valid credentials" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      post api_import_tracks_path, params: { audio_file: file },
        headers: { "Authorization" => "Bearer invalid_token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized without any credentials" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      post api_import_tracks_path, params: { audio_file: file }

      expect(response).to have_http_status(:unauthorized)
    end

    it "reuses existing artist and album" do
      artist = create(:artist, name: "Test Artist")
      album = create(:album, title: "Test Album", artist: artist)

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post api_import_tracks_path, params: { audio_file: file }, headers: auth_headers

      expect(response).to have_http_status(:created)
      track = Track.last
      expect(track.artist).to eq(artist)
      expect(track.album).to eq(album)
    end

    it "enqueues cover art attachment job" do
      allow(MetadataExtractor).to receive(:call).and_return({
        title: "Art Song", artist: "Art Artist", album: "Art Album",
        year: 2024, genre: "Rock", track_number: 1, disc_number: 1,
        duration: 200.0, bitrate: 320,
        cover_art: { data: "fake image data", mime_type: "image/jpeg" }
      })

      file = fixture_file_upload("test.mp3", "audio/mpeg")

      expect {
        post api_import_tracks_path, params: { audio_file: file }, headers: auth_headers
      }.to have_enqueued_job(CoverArtAttachJob)

      expect(response).to have_http_status(:created)
    end
  end
end
