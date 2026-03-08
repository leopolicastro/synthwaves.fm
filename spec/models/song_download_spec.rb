require "rails_helper"

RSpec.describe SongDownload, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:song_download) }

    it { is_expected.to validate_presence_of(:job_id) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:source_type) }
    it { is_expected.to validate_inclusion_of(:source_type).in_array(%w[url search]) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "#generate_webhook_token" do
    it "auto-generates webhook_token on create" do
      download = create(:song_download)
      expect(download.webhook_token).to be_present
    end

    it "does not overwrite an existing webhook_token" do
      download = create(:song_download, webhook_token: "custom-token")
      expect(download.webhook_token).to eq("custom-token")
    end
  end

  describe "#process_track" do
    let(:download) { create(:song_download, status: "queued", total_tracks: 1) }
    let(:file) { StringIO.new("fake mp3 data") }
    let(:metadata) { {"artist" => "Daft Punk", "title" => "Get Lucky", "duration" => 248.0} }

    before do
      allow(ItunesSearch).to receive(:call).and_return({
        artist: "Daft Punk",
        album: "Random Access Memories",
        title: "Get Lucky",
        track_number: 8,
        disc_number: 1,
        genre: "Electronic",
        year: 2013,
        artwork_url: nil
      })
    end

    it "creates artist, album, and track" do
      expect {
        download.process_track(file: file, thumbnail: nil, metadata: metadata)
      }.to change(Track, :count).by(1)
        .and change(Artist, :count).by(1)
        .and change(Album, :count).by(1)

      track = Track.last
      expect(track.title).to eq("Get Lucky")
      expect(track.artist.name).to eq("Daft Punk")
      expect(track.album.title).to eq("Random Access Memories")
      expect(track.audio_file).to be_attached
    end

    it "increments tracks_received" do
      download.process_track(file: file, thumbnail: nil, metadata: metadata)
      expect(download.reload.tracks_received).to eq(1)
    end

    it "transitions status from queued to processing" do
      download.update!(total_tracks: 2)
      download.process_track(file: file, thumbnail: nil, metadata: metadata)
      expect(download.reload.status).to eq("processing")
    end

    it "marks completed when all tracks received" do
      download.process_track(file: file, thumbnail: nil, metadata: metadata)
      expect(download.reload.status).to eq("completed")
    end

    it "falls back to Trafi metadata when iTunes returns nil" do
      allow(ItunesSearch).to receive(:call).and_return(nil)
      download.process_track(file: file, thumbnail: nil, metadata: metadata)

      track = Track.last
      expect(track.title).to eq("Get Lucky")
      expect(track.artist.name).to eq("Daft Punk")
      expect(track.album.title).to eq("Downloads")
    end

    it "attaches thumbnail as cover art when no iTunes artwork" do
      allow(ItunesSearch).to receive(:call).and_return(nil)

      thumbnail = Rack::Test::UploadedFile.new(
        StringIO.new("fake image"),
        "image/jpeg",
        original_filename: "thumb.jpg"
      )
      # Use a real tempfile for the thumbnail since Rack::Test::UploadedFile
      # needs a file path
      thumb_file = Tempfile.new(["thumb", ".jpg"])
      thumb_file.write("fake image data")
      thumb_file.rewind

      uploaded_thumb = ActionDispatch::Http::UploadedFile.new(
        tempfile: thumb_file,
        filename: "thumb.jpg",
        type: "image/jpeg"
      )

      download.process_track(file: file, thumbnail: uploaded_thumb, metadata: metadata)

      album = Track.last.album
      expect(album.cover_image).to be_attached
    ensure
      thumb_file&.close
      thumb_file&.unlink
    end
  end

  describe "#mark_track_failed" do
    let(:download) { create(:song_download, status: "processing", total_tracks: 1) }

    it "increments tracks_failed" do
      download.mark_track_failed(track_number: 1, error: "404 not found")
      expect(download.reload.tracks_failed).to eq(1)
    end

    it "marks as failed when all tracks fail" do
      download.mark_track_failed(track_number: 1, error: "404 not found")
      expect(download.reload.status).to eq("failed")
    end
  end

  describe "#update_status!" do
    it "sets completed when all tracks received" do
      download = create(:song_download, status: "processing", total_tracks: 2, tracks_received: 2)
      download.update_status!
      expect(download.status).to eq("completed")
    end

    it "sets failed when all tracks failed" do
      download = create(:song_download, status: "processing", total_tracks: 2, tracks_failed: 2)
      download.update_status!
      expect(download.status).to eq("failed")
    end

    it "sets partially_failed when some succeeded and some failed" do
      download = create(:song_download, status: "processing", total_tracks: 2, tracks_received: 1, tracks_failed: 1)
      download.update_status!
      expect(download.status).to eq("partially_failed")
    end

    it "does nothing when total_tracks is unknown" do
      download = create(:song_download, status: "processing", total_tracks: nil, tracks_received: 1)
      download.update_status!
      expect(download.status).to eq("processing")
    end
  end

  describe "#finished?" do
    it "returns true when all tracks accounted for" do
      download = build(:song_download, total_tracks: 3, tracks_received: 2, tracks_failed: 1)
      expect(download).to be_finished
    end

    it "returns false when tracks still pending" do
      download = build(:song_download, total_tracks: 3, tracks_received: 1, tracks_failed: 0)
      expect(download).not_to be_finished
    end

    it "returns false when total_tracks is nil" do
      download = build(:song_download, total_tracks: nil, tracks_received: 1)
      expect(download).not_to be_finished
    end
  end
end
