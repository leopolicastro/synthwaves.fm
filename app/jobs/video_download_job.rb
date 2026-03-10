class VideoDownloadJob < ApplicationJob
  queue_as :default

  def perform(video_id, url, user_id:)
    video = Video.find(video_id)
    return if video.file.attached?

    temp_dir = Rails.root.join("tmp/media_downloads/video_#{video_id}_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(temp_dir)

    video.update!(download_status: "downloading", download_error: nil)
    broadcast_status(video, user_id)

    file_path = MediaDownloadService.download_video(url, output_dir: temp_dir.to_s)

    video.update!(status: "processing")

    video.file.attach(
      io: File.open(file_path),
      filename: "#{video_id}.mp4",
      content_type: "video/mp4"
    )

    video.update!(
      download_status: "completed",
      download_error: nil,
      file_format: "mp4",
      file_size: File.size(file_path)
    )
    broadcast_status(video, user_id)

    VideoConversionJob.perform_later(video.id)
  rescue MediaDownloadService::Error, StandardError => e
    video&.update!(download_status: "failed", download_error: e.message.truncate(500), status: "failed", error_message: "Download failed: #{e.message.truncate(500)}")
    broadcast_status(video, user_id) if video
    raise unless e.is_a?(MediaDownloadService::Error)
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  private

  def broadcast_status(video, user_id)
    return unless video

    Turbo::StreamsChannel.broadcast_replace_to(
      "downloads_#{user_id}",
      target: "media-download-video-#{video.id}",
      partial: "youtube_imports/download_status",
      locals: { record: video, type: "video" }
    )
  end
end
