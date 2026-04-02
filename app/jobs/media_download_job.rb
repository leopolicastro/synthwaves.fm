class MediaDownloadJob < ApplicationJob
  include DownloadBroadcastable

  queue_as :imports

  PERMANENT_ERRORS = [
    /Video unavailable/i,
    /Private video/i,
    /removed by the uploader/i,
    /not available in your country/i,
    /blocked it.*on copyright grounds/i,
    /one or more of whom have blocked/i,
    /Music Premium members/i,
    /live stream recording is not available/i,
    /has not made this video available/i
  ].freeze

  retry_on MediaDownloadService::RateLimitError,
    wait: :polynomially_longer,
    attempts: 5 do |job, error|
      Track.find_by(id: job.arguments.first)
        &.update!(download_status: "failed",
          download_error: "Rate limit retries exhausted: #{error.message}".truncate(500))
    end

  def perform(track_id, url, user_id:)
    track = Track.find(track_id)
    return if track.audio_file.attached?

    temp_dir = Rails.root.join("tmp/media_downloads/track_#{track_id}_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(temp_dir)

    track.update!(download_status: "downloading", download_error: nil)
    broadcast_download_status(track, user_id, type: "track")

    file_path = MediaDownloadService.download_audio(url, output_dir: temp_dir.to_s)

    track.audio_file.attach(
      io: File.open(file_path),
      filename: "#{track_id}.mp3",
      content_type: "audio/mpeg"
    )

    metadata = begin
      MetadataExtractor.call(file_path)
    rescue WahWah::WahWahArgumentError
      {}
    end

    track.update!(
      download_status: "completed",
      download_error: nil,
      duration: metadata[:duration] || track.duration,
      bitrate: metadata[:bitrate] || track.bitrate,
      file_format: "mp3",
      file_size: File.size(file_path)
    )

    enrich_from_embedded_metadata(track, metadata) if track.youtube_video_id.present?

    broadcast_download_status(track, user_id, type: "track")
  rescue MediaDownloadService::RateLimitError
    track&.update!(download_status: "downloading", download_error: "Rate limited, retrying...")
    broadcast_download_status(track, user_id, type: "track") if track
    raise
  rescue MediaDownloadService::Error => e
    Rails.logger.error("[MediaDownloadJob] #{e.class}: #{e.message}")
    if track && permanent_error?(e.message)
      delete_permanently_failed_track(track, e.message)
    elsif track
      track.update!(download_status: "failed", download_error: e.message.truncate(500))
      broadcast_download_status(track, user_id, type: "track")
    end
  rescue => e
    track&.update!(download_status: "failed", download_error: e.message.truncate(500))
    broadcast_download_status(track, user_id, type: "track") if track
    raise
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  private

  def permanent_error?(message)
    PERMANENT_ERRORS.any? { |pattern| message.match?(pattern) }
  end

  def delete_permanently_failed_track(track, error_message)
    album = track.album
    artist = track.artist
    Rails.logger.info(
      "[YouTubeCleanup] Deleted track ##{track.id} \"#{track.title}\" " \
      "by \"#{artist.name}\" (youtube: #{track.youtube_video_id}) -- " \
      "reason: #{error_message.truncate(200)}"
    )
    track.destroy!
    album.destroy! if album.tracks.none?
    artist.destroy! if artist.tracks.none?
  end

  def enrich_from_embedded_metadata(track, metadata)
    if metadata[:artist].present? && metadata[:artist] != track.artist.name
      artist = track.user.artists.find_or_create_by!(name: metadata[:artist])
      track.update!(artist: artist)
    end

    if metadata[:title].present? && metadata[:title] != track.title
      track.update!(title: metadata[:title])
    end

    if metadata[:album].present? && track.album.title == YoutubeVideoImportService::SINGLES_ALBUM_TITLE
      album = track.user.albums.find_or_create_by!(title: metadata[:album], artist: track.artist)
      track.update!(album: album)
    end
  end
end
