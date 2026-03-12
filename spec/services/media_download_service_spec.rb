require "rails_helper"

RSpec.describe MediaDownloadService do
  let(:service) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  let(:not_live_metadata) { ['{"is_live": false}', instance_double(Process::Status, success?: true)] }

  after { FileUtils.rm_rf(temp_dir) }

  describe ".download_audio" do
    it "calls yt-dlp with correct audio extraction flags" do
      mp3_path = File.join(temp_dir, "abc123.mp3")
      FileUtils.touch(mp3_path)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download",
        "https://youtube.com/watch?v=abc123"
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp",
        "-x", "--audio-format", "mp3", "--audio-quality", "0",
        "--no-playlist",
        "-o", File.join(temp_dir, "%(id)s.%(ext)s"),
        "https://youtube.com/watch?v=abc123"
      ).and_return(["Done\n", instance_double(Process::Status, success?: true)])

      result = described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      expect(result).to eq(mp3_path)
    end

    it "raises Error when yt-dlp fails" do
      allow(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(
        ["ERROR: Video unavailable\n", instance_double(Process::Status, success?: false)]
      )

      expect {
        described_class.download_audio("https://youtube.com/watch?v=bad", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::Error, /Video unavailable/)
    end

    it "raises Error when no mp3 file is found after download" do
      allow(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(
        ["Done\n", instance_double(Process::Status, success?: true)]
      )

      expect {
        described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::Error, /No mp3 file found/)
    end

    it "raises Error for live streams" do
      live_metadata = ['{"is_live": true}', instance_double(Process::Status, success?: true)]

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(live_metadata)

      expect {
        described_class.download_audio("https://youtube.com/watch?v=live", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::Error, /Cannot download a live stream/)
    end
  end

  describe ".download_video" do
    it "calls yt-dlp with correct video download flags" do
      mp4_path = File.join(temp_dir, "abc123.mp4")
      FileUtils.touch(mp4_path)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download",
        "https://youtube.com/watch?v=abc123"
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp",
        "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best",
        "--merge-output-format", "mp4",
        "--no-playlist",
        "-o", File.join(temp_dir, "%(id)s.%(ext)s"),
        "https://youtube.com/watch?v=abc123"
      ).and_return(["Done\n", instance_double(Process::Status, success?: true)])

      result = described_class.download_video("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      expect(result).to eq(mp4_path)
    end

    it "raises Error when yt-dlp fails" do
      allow(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-f", any_args
      ).and_return(
        ["ERROR: Unsupported URL\n", instance_double(Process::Status, success?: false)]
      )

      expect {
        described_class.download_video("https://youtube.com/watch?v=bad", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::Error, /Unsupported URL/)
    end

    it "raises Error for live streams" do
      live_metadata = ['{"is_live": true}', instance_double(Process::Status, success?: true)]

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(live_metadata)

      expect {
        described_class.download_video("https://youtube.com/watch?v=live", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::Error, /Cannot download a live stream/)
    end
  end

  describe "live stream detection" do
    it "proceeds when metadata check fails" do
      mp3_path = File.join(temp_dir, "abc123.mp3")
      FileUtils.touch(mp3_path)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(["ERROR\n", instance_double(Process::Status, success?: false)])

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(["Done\n", instance_double(Process::Status, success?: true)])

      result = described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      expect(result).to eq(mp3_path)
    end

    it "proceeds when metadata is not valid JSON" do
      mp3_path = File.join(temp_dir, "abc123.mp3")
      FileUtils.touch(mp3_path)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "--dump-json", "--no-download", anything
      ).and_return(["not json", instance_double(Process::Status, success?: true)])

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(["Done\n", instance_double(Process::Status, success?: true)])

      result = described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      expect(result).to eq(mp3_path)
    end
  end
end
