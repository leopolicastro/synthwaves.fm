require "rails_helper"

RSpec.describe "Tracks", type: :request do
  let(:user) { create(:user, admin: true) }

  before { login_user(user) }

  describe "GET /tracks" do
    it "returns success" do
      get tracks_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tracks/:id" do
    let(:track) { create(:track) }

    it "returns success" do
      get track_path(track)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tracks/new" do
    it "returns success" do
      get new_track_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tracks" do
    it "creates a track from uploaded audio file" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      expect {
        post tracks_path, params: {audio_file: file}
      }.to change(Track, :count).by(1)

      track = Track.last
      expect(track.title).to eq("Test Song")
      expect(track.artist.name).to eq("Test Artist")
      expect(track.album.title).to eq("Test Album")
      expect(response).to redirect_to(track_path(track))
    end

    it "returns unprocessable_content without a file" do
      post tracks_path
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "reuses existing artist and album" do
      artist = create(:artist, name: "Test Artist")
      album = create(:album, title: "Test Album", artist: artist)

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      track = Track.last
      expect(track.artist).to eq(artist)
      expect(track.album).to eq(album)
    end

    it "does not overwrite existing album cover art" do
      artist = create(:artist, name: "Cover Artist")
      album = create(:album, title: "Cover Album", artist: artist)
      album.cover_image.attach(
        io: StringIO.new("existing cover"),
        filename: "existing.jpg",
        content_type: "image/jpeg"
      )
      original_blob_id = album.cover_image.blob.id

      allow(MetadataExtractor).to receive(:call).and_return({
        title: "Cover Song", artist: "Cover Artist", album: "Cover Album",
        year: 2024, genre: "Pop", track_number: 1, disc_number: 1,
        duration: 200.0, bitrate: 320,
        cover_art: {data: "new image data", mime_type: "image/jpeg"}
      })

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      expect(album.reload.cover_image.blob.id).to eq(original_blob_id)
    end

    it "attaches cover art to album when metadata includes it" do
      allow(MetadataExtractor).to receive(:call).and_return({
        title: "Cover Song", artist: "Cover Artist", album: "Cover Album",
        year: 2024, genre: "Pop", track_number: 1, disc_number: 1,
        duration: 200.0, bitrate: 320,
        cover_art: {data: "fake image data", mime_type: "image/jpeg"}
      })

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      track = Track.last
      expect(track.album.cover_image.attached?).to be true
    end
  end

  describe "PATCH /tracks/:id" do
    let(:track) { create(:track) }

    it "updates the track" do
      patch track_path(track), params: {track: {title: "New Title"}}
      expect(track.reload.title).to eq("New Title")
      expect(response).to redirect_to(track_path(track))
    end

    it "rejects blank title" do
      patch track_path(track), params: {track: {title: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /tracks/:id" do
    let!(:track) { create(:track) }

    it "deletes the track" do
      expect {
        delete track_path(track)
      }.to change(Track, :count).by(-1)
      expect(response).to redirect_to(tracks_path)
    end
  end

  describe "authorization" do
    let(:non_admin) { create(:user, admin: false) }
    let(:track) { create(:track) }

    before { login_user(non_admin) }

    it "redirects non-admin from edit" do
      get edit_track_path(track)
      expect(response).to redirect_to(tracks_path)
    end

    it "redirects non-admin from update" do
      patch track_path(track), params: {track: {title: "Hacked"}}
      expect(response).to redirect_to(tracks_path)
      expect(track.reload.title).not_to eq("Hacked")
    end

    it "redirects non-admin from destroy" do
      delete track_path(track)
      expect(response).to redirect_to(tracks_path)
      expect(Track.exists?(track.id)).to be true
    end
  end

  describe "GET /tracks/:id/stream" do
    let(:track) { create(:track) }

    it "returns not_found when no audio file is attached" do
      get stream_track_path(track)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects when audio file is attached" do
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )
      get stream_track_path(track)
      expect(response).to have_http_status(:redirect)
    end
  end
end
