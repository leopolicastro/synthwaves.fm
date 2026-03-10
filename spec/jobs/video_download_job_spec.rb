require "rails_helper"

RSpec.describe VideoDownloadJob, type: :job do
  let(:user) { create(:user) }
  let(:video) { create(:video, :processing, user: user, youtube_video_id: "abc123") }
  let(:url) { "https://youtube.com/watch?v=abc123" }
  let(:temp_mp4) { Tempfile.new(["test", ".mp4"]) }

  before do
    File.write(temp_mp4.path, "fake mp4 data")
  end

  after { temp_mp4.close! }

  describe "#perform" do
    it "downloads video and attaches it" do
      allow(MediaDownloadService).to receive(:download_video).and_return(temp_mp4.path)

      described_class.perform_now(video.id, url, user_id: user.id)
      video.reload

      expect(video.file).to be_attached
      expect(video.download_status).to eq("completed")
      expect(video.file_format).to eq("mp4")
    end

    it "enqueues VideoConversionJob after download" do
      allow(MediaDownloadService).to receive(:download_video).and_return(temp_mp4.path)

      expect {
        described_class.perform_now(video.id, url, user_id: user.id)
      }.to have_enqueued_job(VideoConversionJob).with(video.id)
    end

    it "skips if file is already attached" do
      video.file.attach(io: StringIO.new("existing"), filename: "existing.mp4", content_type: "video/mp4")

      expect(MediaDownloadService).not_to receive(:download_video)
      described_class.perform_now(video.id, url, user_id: user.id)
    end

    it "sets failed status on download error" do
      allow(MediaDownloadService).to receive(:download_video)
        .and_raise(MediaDownloadService::Error, "yt-dlp failed: download error")

      described_class.perform_now(video.id, url, user_id: user.id)
      video.reload

      expect(video.download_status).to eq("failed")
      expect(video.download_error).to include("download error")
      expect(video.status).to eq("failed")
      expect(video.error_message).to include("Download failed")
    end

    it "cleans up temp directory" do
      allow(MediaDownloadService).to receive(:download_video).and_return(temp_mp4.path)

      described_class.perform_now(video.id, url, user_id: user.id)

      temp_dirs = Dir.glob(Rails.root.join("tmp/media_downloads/video_#{video.id}_*"))
      expect(temp_dirs).to be_empty
    end
  end
end
