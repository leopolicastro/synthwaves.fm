require "rails_helper"

RSpec.describe "Downloads", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "POST /downloads" do
    it "creates a download for an album and enqueues job" do
      album = create(:album)

      expect {
        post downloads_path, params: {downloadable_type: "Album", downloadable_id: album.id}
      }.to change(Download, :count).by(1)
        .and have_enqueued_job(DownloadZipJob)

      download = Download.last
      expect(download.downloadable).to eq(album)
      expect(download.status).to eq("pending")
      expect(download.user).to eq(user)
    end

    it "creates a download for a playlist owned by the user" do
      playlist = create(:playlist, user: user)

      expect {
        post downloads_path, params: {downloadable_type: "Playlist", downloadable_id: playlist.id}
      }.to change(Download, :count).by(1)
    end

    it "rejects downloading another user's playlist" do
      other_playlist = create(:playlist)

      post downloads_path, params: {downloadable_type: "Playlist", downloadable_id: other_playlist.id}

      expect(response).to redirect_to(library_path)
      expect(flash[:alert]).to eq("Could not find the requested item.")
    end

    it "creates a library export download" do
      expect {
        post downloads_path, params: {downloadable_type: "Library"}
      }.to change(Download, :count).by(1)

      download = Download.last
      expect(download.downloadable_type).to eq("Library")
      expect(download.downloadable_id).to be_nil
    end

    it "deduplicates existing pending downloads" do
      album = create(:album)
      existing = create(:download, user: user, downloadable: album, downloadable_type: "Album", status: "processing")

      expect {
        post downloads_path, params: {downloadable_type: "Album", downloadable_id: album.id}
      }.not_to change(Download, :count)

      expect(response).to redirect_to(download_path(existing))
    end

    it "rejects invalid downloadable_type" do
      post downloads_path, params: {downloadable_type: "User", downloadable_id: 1}

      expect(response).to redirect_to(library_path)
      expect(flash[:alert]).to eq("Invalid download type.")
    end

    it "requires authentication" do
      reset!
      post downloads_path, params: {downloadable_type: "Library"}
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /downloads/:id" do
    it "shows the download status page" do
      download = create(:download, user: user)

      get download_path(download)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Download")
    end

    it "does not show another user's download" do
      other_download = create(:download)

      get download_path(other_download)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /downloads/:id/file" do
    it "redirects to the file when ready" do
      download = create(:download, :ready, user: user)
      download.file.attach(
        io: StringIO.new("fake zip content"),
        filename: "test.zip",
        content_type: "application/zip"
      )

      get file_download_path(download)

      expect(response).to have_http_status(:redirect)
    end

    it "redirects with alert when not ready" do
      download = create(:download, user: user, status: "processing")

      get file_download_path(download)

      expect(response).to redirect_to(download_path(download))
      expect(flash[:alert]).to eq("Download is not ready yet.")
    end
  end
end
