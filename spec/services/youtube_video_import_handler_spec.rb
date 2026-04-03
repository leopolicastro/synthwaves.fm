require "rails_helper"

RSpec.describe YoutubeVideoImportHandler do
  let(:user) { create(:user, youtube_api_key: "test_key") }

  describe ".call" do
    it "raises error for playlist URLs" do
      expect {
        described_class.call(url: "https://www.youtube.com/playlist?list=PLtest", user: user)
      }.to raise_error(described_class::Error, /not supported for playlists/)
    end

    it "raises error for invalid URLs" do
      expect {
        described_class.call(url: "https://example.com", user: user)
      }.to raise_error(described_class::Error, /valid YouTube URL/)
    end

    it "returns existing video without creating a duplicate" do
      existing = create(:video, user: user, youtube_video_id: "dQw4w9WgXcQ")

      result = described_class.call(
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        user: user
      )

      expect(result.video).to eq(existing)
      expect(result.status).to eq(:existing)
      expect(Video.count).to eq(1)
    end

    it "creates a video and enqueues download when using YouTube API" do
      details = {video_id: "dQw4w9WgXcQ", title: "Test Video", channel_name: "Test", duration: 120.0}
      api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).with(api_key: "test_key").and_return(api)
      allow(api).to receive(:fetch_video_details).with(["dQw4w9WgXcQ"]).and_return([details])

      result = nil
      expect {
        result = described_class.call(
          url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
          user: user
        )
      }.to change(Video, :count).by(1)

      expect(result.status).to eq(:created)
      expect(result.video.title).to eq("Test Video")
      expect(result.video.youtube_video_id).to eq("dQw4w9WgXcQ")
      expect(result.video.duration).to eq(120.0)
      expect(result.video.status).to eq("processing")
      expect(VideoDownloadJob).to have_been_enqueued.with(
        result.video.id, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", user_id: user.id
      )
    end

    it "falls back to yt-dlp metadata when no API key" do
      user.update!(youtube_api_key: nil)
      metadata = {title: "Fallback Video", duration: 90.0}
      allow(MediaDownloadService).to receive(:fetch_metadata)
        .with("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        .and_return(metadata)

      result = described_class.call(
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        user: user
      )

      expect(result.status).to eq(:created)
      expect(result.video.title).to eq("Fallback Video")
    end

    it "raises YoutubeAPIService::Error when video not found via API" do
      api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).and_return(api)
      allow(api).to receive(:fetch_video_details).with(["R-FxmoVM7X4"]).and_return([nil])

      expect {
        described_class.call(url: "https://www.youtube.com/watch?v=R-FxmoVM7X4", user: user)
      }.to raise_error(YoutubeAPIService::Error, "Video not found")
    end
  end
end
