class MediaDownloadService
  class Error < StandardError; end

  def self.download_audio(url, output_dir:)
    new.download_audio(url, output_dir: output_dir)
  end

  def self.download_video(url, output_dir:)
    new.download_video(url, output_dir: output_dir)
  end

  def self.fetch_metadata(url)
    new.fetch_metadata(url)
  end

  def self.fetch_playlist_metadata(url)
    new.fetch_playlist_metadata(url)
  end

  def fetch_metadata(url)
    json, stderr, status = Open3.capture3("yt-dlp", "--dump-json", "--no-download", "--no-playlist", url)
    raise Error, "Failed to fetch video metadata: #{stderr.truncate(500)}" unless status.success?

    data = JSON.parse(json)
    raise Error, "Cannot download a live stream" if data["is_live"] == true

    {
      video_id: data["id"],
      title: data["title"],
      channel_name: data["channel"] || data["uploader"],
      duration: data["duration"]&.to_f,
      thumbnail_url: data["thumbnail"]
    }
  rescue JSON::ParserError
    raise Error, "Failed to parse video metadata"
  end

  def fetch_playlist_metadata(url)
    json, stderr, status = Open3.capture3("yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download", url)
    raise Error, "Failed to fetch playlist metadata: #{stderr.truncate(500)}" unless status.success?

    data = JSON.parse(json)

    {
      title: data["title"],
      channel_name: data["channel"] || data["uploader"],
      thumbnail_url: best_thumbnail(data["thumbnails"]),
      entries: (data["entries"] || []).each_with_index.map { |entry, index|
        {
          video_id: entry["id"],
          title: entry["title"],
          position: index,
          duration: entry["duration"]&.to_f
        }
      }
    }
  rescue JSON::ParserError
    raise Error, "Failed to parse playlist metadata"
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
    metadata_json, _stderr, status = Open3.capture3("yt-dlp", "--dump-json", "--no-download", url)
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

  def best_thumbnail(thumbnails)
    return nil if thumbnails.blank?

    thumbnails.max_by { |t| t["preference"] || 0 }&.dig("url")
  end

  def find_output_file(dir, expected_ext)
    pattern = File.join(dir, "*.#{expected_ext}")
    files = Dir.glob(pattern)
    raise Error, "No #{expected_ext} file found after download" if files.empty?
    files.first
  end
end
