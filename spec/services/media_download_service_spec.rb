require "rails_helper"

RSpec.describe MediaDownloadService do
  let(:service) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  let(:not_live_metadata) { ['{"is_live": false}', "", instance_double(Process::Status, success?: true)] }

  after { FileUtils.rm_rf(temp_dir) }

  describe ".download_audio" do
    it "calls yt-dlp with correct audio extraction flags" do
      mp3_path = File.join(temp_dir, "abc123.mp3")
      FileUtils.touch(mp3_path)

      expect(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist",
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
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
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

    it "raises RateLimitError on HTTP 429" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(
        ["WARNING: [youtube] Unable to download webpage: HTTP Error 429: Too Many Requests\n",
          instance_double(Process::Status, success?: false)]
      )

      expect {
        described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::RateLimitError, /rate limited/)
    end

    it "raises RateLimitError on Sign in to confirm" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(not_live_metadata)

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(
        ["ERROR: Sign in to confirm you are not a bot\n",
          instance_double(Process::Status, success?: false)]
      )

      expect {
        described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::RateLimitError, /rate limited/)
    end

    it "raises Error when no mp3 file is found after download" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
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
      live_metadata = ['{"is_live": true}', "", instance_double(Process::Status, success?: true)]

      expect(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
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

      expect(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist",
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
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
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
      live_metadata = ['{"is_live": true}', "", instance_double(Process::Status, success?: true)]

      expect(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(live_metadata)

      expect {
        described_class.download_video("https://youtube.com/watch?v=live", output_dir: temp_dir)
      }.to raise_error(MediaDownloadService::Error, /Cannot download a live stream/)
    end
  end

  describe ".fetch_metadata" do
    let(:ytdlp_json) do
      {
        id: "R-FxmoVM7X4",
        title: "Daft Punk - Around The World (Official Video)",
        channel: "Daft Punk",
        uploader: "Daft Punk",
        duration: 225.3,
        thumbnail: "https://i.ytimg.com/vi/R-FxmoVM7X4/maxresdefault.jpg",
        is_live: false
      }.to_json
    end

    it "returns structured metadata from yt-dlp" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist",
        "https://youtube.com/watch?v=R-FxmoVM7X4"
      ).and_return([ytdlp_json, "", instance_double(Process::Status, success?: true)])

      result = described_class.fetch_metadata("https://youtube.com/watch?v=R-FxmoVM7X4")

      expect(result).to eq(
        video_id: "R-FxmoVM7X4",
        title: "Daft Punk - Around The World (Official Video)",
        channel_name: "Daft Punk",
        duration: 225.3,
        thumbnail_url: "https://i.ytimg.com/vi/R-FxmoVM7X4/maxresdefault.jpg"
      )
    end

    it "falls back to uploader when channel is absent" do
      json = {id: "abc", title: "Test", uploader: "UploaderName", duration: 60, is_live: false}.to_json
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return([json, "", instance_double(Process::Status, success?: true)])

      result = described_class.fetch_metadata("https://youtube.com/watch?v=abc")

      expect(result[:channel_name]).to eq("UploaderName")
    end

    it "raises Error when yt-dlp fails" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(["", "ERROR\n", instance_double(Process::Status, success?: false)])

      expect {
        described_class.fetch_metadata("https://youtube.com/watch?v=bad")
      }.to raise_error(MediaDownloadService::Error, /Failed to fetch video metadata/)
    end

    it "raises Error for live streams" do
      json = {id: "live1", title: "Live Stream", is_live: true}.to_json
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return([json, "", instance_double(Process::Status, success?: true)])

      expect {
        described_class.fetch_metadata("https://youtube.com/watch?v=live1")
      }.to raise_error(MediaDownloadService::Error, /Cannot download a live stream/)
    end

    it "raises Error when JSON is unparseable" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(["not json", "", instance_double(Process::Status, success?: true)])

      expect {
        described_class.fetch_metadata("https://youtube.com/watch?v=abc")
      }.to raise_error(MediaDownloadService::Error, "Failed to parse video metadata")
    end

    it "parses JSON correctly when stderr contains warnings" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return([
        ytdlp_json,
        "WARNING: Unable to extract uploader id\nWARNING: Falling back to another extractor\n",
        instance_double(Process::Status, success?: true)
      ])

      result = described_class.fetch_metadata("https://youtube.com/watch?v=R-FxmoVM7X4")

      expect(result[:video_id]).to eq("R-FxmoVM7X4")
      expect(result[:title]).to eq("Daft Punk - Around The World (Official Video)")
    end
  end

  describe ".fetch_playlist_metadata" do
    let(:ytdlp_playlist_json) do
      {
        id: "PLtest123",
        title: "Synthwave Essentials",
        channel: "MusicChannel",
        uploader: "MusicChannel",
        thumbnails: [
          {"url" => "https://example.com/small.jpg", "preference" => -1},
          {"url" => "https://example.com/large.jpg", "preference" => 5}
        ],
        entries: [
          {"id" => "vid1", "title" => "Artist - Song One", "duration" => 180.0},
          {"id" => "vid2", "title" => "Artist - Song Two", "duration" => 240.5}
        ]
      }.to_json
    end

    it "returns structured playlist metadata from yt-dlp" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", anything
      ).and_return([ytdlp_playlist_json, "", instance_double(Process::Status, success?: true)])

      result = described_class.fetch_playlist_metadata("https://youtube.com/playlist?list=PLtest123")

      expect(result[:title]).to eq("Synthwave Essentials")
      expect(result[:channel_name]).to eq("MusicChannel")
      expect(result[:thumbnail_url]).to eq("https://example.com/large.jpg")
      expect(result[:entries].length).to eq(2)
      expect(result[:entries].first).to eq(video_id: "vid1", title: "Artist - Song One", position: 0, duration: 180.0)
      expect(result[:entries].last).to eq(video_id: "vid2", title: "Artist - Song Two", position: 1, duration: 240.5)
    end

    it "selects the highest-preference thumbnail" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", anything
      ).and_return([ytdlp_playlist_json, "", instance_double(Process::Status, success?: true)])

      result = described_class.fetch_playlist_metadata("https://youtube.com/playlist?list=PLtest123")

      expect(result[:thumbnail_url]).to eq("https://example.com/large.jpg")
    end

    it "returns nil thumbnail when thumbnails array is absent" do
      json = {id: "PL1", title: "Test", entries: []}.to_json
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", anything
      ).and_return([json, "", instance_double(Process::Status, success?: true)])

      result = described_class.fetch_playlist_metadata("https://youtube.com/playlist?list=PL1")

      expect(result[:thumbnail_url]).to be_nil
    end

    it "raises Error when yt-dlp fails" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", anything
      ).and_return(["", "ERROR\n", instance_double(Process::Status, success?: false)])

      expect {
        described_class.fetch_playlist_metadata("https://youtube.com/playlist?list=PLbad")
      }.to raise_error(MediaDownloadService::Error, /Failed to fetch playlist metadata/)
    end

    it "raises Error when JSON is unparseable" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", anything
      ).and_return(["not json", "", instance_double(Process::Status, success?: true)])

      expect {
        described_class.fetch_playlist_metadata("https://youtube.com/playlist?list=PL1")
      }.to raise_error(MediaDownloadService::Error, "Failed to parse playlist metadata")
    end

    it "parses JSON correctly when stderr contains warnings" do
      allow(Open3).to receive(:capture3).with(
        "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", anything
      ).and_return([
        ytdlp_playlist_json,
        "WARNING: [youtube] Skipping player responses from android clients\n",
        instance_double(Process::Status, success?: true)
      ])

      result = described_class.fetch_playlist_metadata("https://youtube.com/playlist?list=PLtest123")

      expect(result[:title]).to eq("Synthwave Essentials")
      expect(result[:entries].length).to eq(2)
    end
  end

  describe "live stream detection" do
    it "proceeds when metadata check fails" do
      mp3_path = File.join(temp_dir, "abc123.mp3")
      FileUtils.touch(mp3_path)

      expect(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(["", "ERROR\n", instance_double(Process::Status, success?: false)])

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(["Done\n", instance_double(Process::Status, success?: true)])

      result = described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      expect(result).to eq(mp3_path)
    end

    it "proceeds when metadata is not valid JSON" do
      mp3_path = File.join(temp_dir, "abc123.mp3")
      FileUtils.touch(mp3_path)

      expect(Open3).to receive(:capture3).with(
        "yt-dlp", "--dump-json", "--no-download", "--no-playlist", anything
      ).and_return(["not json", "", instance_double(Process::Status, success?: true)])

      expect(Open3).to receive(:capture2e).with(
        "yt-dlp", "-x", any_args
      ).and_return(["Done\n", instance_double(Process::Status, success?: true)])

      result = described_class.download_audio("https://youtube.com/watch?v=abc123", output_dir: temp_dir)
      expect(result).to eq(mp3_path)
    end
  end
end
