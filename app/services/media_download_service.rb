class MediaDownloadService
  class Error < StandardError; end

  def self.download_audio(url, output_dir:)
    new.download_audio(url, output_dir: output_dir)
  end

  def self.download_video(url, output_dir:)
    new.download_video(url, output_dir: output_dir)
  end

  def download_audio(url, output_dir:)
    reject_live_stream!(url)
    output_template = File.join(output_dir, "%(id)s.%(ext)s")

    run_yt_dlp(
      "-x", "--audio-format", "mp3", "--audio-quality", "0",
      "--no-playlist",
      "-o", output_template,
      url
    )

    find_output_file(output_dir, "mp3")
  end

  def download_video(url, output_dir:)
    reject_live_stream!(url)
    output_template = File.join(output_dir, "%(id)s.%(ext)s")

    run_yt_dlp(
      "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best",
      "--merge-output-format", "mp4",
      "--no-playlist",
      "-o", output_template,
      url
    )

    find_output_file(output_dir, "mp4")
  end

  private

  def reject_live_stream!(url)
    metadata_json, status = Open3.capture2e("yt-dlp", "--dump-json", "--no-download", url)
    return unless status.success?

    metadata = JSON.parse(metadata_json)
    raise Error, "Cannot download a live stream" if metadata["is_live"] == true
  rescue JSON::ParserError
    # If we can't parse metadata, let the download attempt proceed
  end

  def run_yt_dlp(*args)
    stdout_stderr, status = Open3.capture2e("yt-dlp", *args)

    unless status.success?
      raise Error, "yt-dlp failed: #{stdout_stderr.truncate(500)}"
    end

    stdout_stderr
  end

  def find_output_file(dir, expected_ext)
    pattern = File.join(dir, "*.#{expected_ext}")
    files = Dir.glob(pattern)
    raise Error, "No #{expected_ext} file found after download" if files.empty?
    files.first
  end
end
