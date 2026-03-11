require "rails_helper"
require "zip"

RSpec.describe DownloadZipJob, type: :job do
  let(:user) { create(:user) }
  let(:audio_file) { File.open(Rails.root.join("spec/fixtures/files/test.mp3")) }

  def attach_audio(track)
    track.audio_file.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )
  end

  describe "album download" do
    it "creates a zip with album tracks" do
      album = create(:album)
      track1 = create(:track, album: album, artist: album.artist, track_number: 1, title: "First")
      track2 = create(:track, album: album, artist: album.artist, track_number: 2, title: "Second")
      attach_audio(track1)
      attach_audio(track2)
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("ready")
      expect(download.file).to be_attached
      expect(download.processed_tracks).to eq(2)
      expect(download.total_tracks).to eq(2)
    end
  end

  describe "playlist download" do
    it "creates a zip with playlist tracks" do
      playlist = create(:playlist, user: user)
      track = create(:track, title: "Playlist Song")
      attach_audio(track)
      create(:playlist_track, playlist: playlist, track: track, position: 1)
      download = create(:download, user: user, downloadable: playlist, downloadable_type: "Playlist")

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("ready")
      expect(download.file).to be_attached
    end
  end

  describe "library download" do
    it "creates a zip with all tracks that have audio files" do
      track = create(:track, title: "Library Track")
      attach_audio(track)
      download = create(:download, :for_library, user: user)

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("ready")
      expect(download.file).to be_attached
    end
  end

  describe "skipping tracks without audio" do
    it "skips tracks with no audio file attached" do
      album = create(:album)
      normal_track = create(:track, album: album, artist: album.artist, title: "Normal")
      attach_audio(normal_track)
      create(:track, album: album, artist: album.artist, title: "YouTube Only", youtube_video_id: "yt123")
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("ready")
      expect(download.total_tracks).to eq(1)
    end

    it "includes YouTube tracks that have downloaded audio files" do
      album = create(:album)
      yt_track = create(:track, album: album, artist: album.artist, title: "YouTube Downloaded", youtube_video_id: "yt456")
      attach_audio(yt_track)
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("ready")
      expect(download.total_tracks).to eq(1)
      expect(download.file).to be_attached
    end
  end

  describe "error handling" do
    it "marks download as failed when no downloadable tracks exist" do
      album = create(:album)
      create(:track, album: album, artist: album.artist, youtube_video_id: "yt123")
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("failed")
      expect(download.error_message).to eq("No downloadable tracks found.")
    end

    it "marks download as failed on unexpected errors" do
      download = create(:download, :for_library, user: user)
      allow(Track).to receive(:includes).and_raise(StandardError.new("boom"))

      expect {
        DownloadZipJob.perform_now(download.id)
      }.to raise_error(StandardError, "boom")

      download.reload
      expect(download.status).to eq("failed")
      expect(download.error_message).to include("boom")
    end
  end

  describe "temp file cleanup" do
    it "removes temp zip file after processing" do
      album = create(:album)
      track = create(:track, album: album, artist: album.artist)
      attach_audio(track)
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      DownloadZipJob.perform_now(download.id)

      tmp_files = Dir.glob(Rails.root.join("tmp/downloads/download_#{download.id}_*"))
      expect(tmp_files).to be_empty
    end
  end

  describe "status lifecycle" do
    it "transitions from pending to processing to ready" do
      album = create(:album)
      track = create(:track, album: album, artist: album.artist)
      attach_audio(track)
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      statuses = []
      allow_any_instance_of(Download).to receive(:broadcast_status) do |dl|
        statuses << dl.status
      end

      DownloadZipJob.perform_now(download.id)

      expect(statuses).to include("processing", "ready")
    end
  end

  describe "duplicate filenames" do
    it "deduplicates tracks with the same name" do
      album = create(:album)
      track1 = create(:track, album: album, artist: album.artist, title: "Same", track_number: 1)
      track2 = create(:track, album: album, artist: album.artist, title: "Same", track_number: 1)
      attach_audio(track1)
      attach_audio(track2)
      download = create(:download, user: user, downloadable: album, downloadable_type: "Album")

      DownloadZipJob.perform_now(download.id)

      download.reload
      expect(download.status).to eq("ready")
      expect(download.total_tracks).to eq(2)
    end
  end
end
