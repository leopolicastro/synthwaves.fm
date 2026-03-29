class VideoConversionJob < ApplicationJob
  queue_as :conversion

  def perform(video_id)
    video = Video.find(video_id)
    return unless video.file.attached?

    video.file.open do |source_file|
      output_path = "#{source_file.path}.mp4"
      thumbnail_path = "#{source_file.path}_thumb.jpg"

      metadata = VideoMetadataExtractor.call(source_file.path)
      strategy = conversion_strategy(metadata)

      case strategy
      when :remux
        remux_to_mp4(source_file.path, output_path)
        final_path = output_path
      when :transcode_audio
        transcode_audio_to_mp4(source_file.path, output_path)
        final_path = output_path
      when :full
        convert_to_mp4(source_file.path, output_path)
        final_path = output_path
      else
        final_path = source_file.path
      end

      converted = strategy != :none

      generate_thumbnail(final_path, thumbnail_path, metadata[:duration])

      if converted
        video.file.attach(
          io: File.open(output_path),
          filename: video.file.filename.to_s.sub(/\.\w+$/, ".mp4"),
          content_type: "video/mp4"
        )
      end

      if File.exist?(thumbnail_path)
        video.thumbnail.attach(
          io: File.open(thumbnail_path),
          filename: "thumbnail.jpg",
          content_type: "image/jpeg"
        )
      end

      final_metadata = converted ? VideoMetadataExtractor.call(output_path) : metadata

      video.update!(
        status: "ready",
        duration: final_metadata[:duration] || video.duration,
        width: final_metadata[:width] || video.width,
        height: final_metadata[:height] || video.height,
        video_codec: final_metadata[:video_codec] || video.video_codec,
        audio_codec: final_metadata[:audio_codec] || video.audio_codec,
        bitrate: final_metadata[:bitrate] || video.bitrate,
        audio_channels: final_metadata[:audio_channels] || video.audio_channels,
        file_format: converted ? "mp4" : video.file_format,
        file_size: File.size(final_path)
      )
    rescue => e
      video.update!(status: "failed", error_message: e.message)
    ensure
      FileUtils.rm_f(output_path) if output_path
      FileUtils.rm_f(thumbnail_path) if thumbnail_path
    end
  end

  private

  MP4_CONTAINERS = %w[mov,mp4,m4a,3gp,3g2,mj2 mp4 m4v].freeze

  def conversion_strategy(metadata)
    return :full unless metadata[:video_codec]

    h264 = metadata[:video_codec] == "h264"
    aac = metadata[:audio_codec]&.match?(/aac/)
    mp4_container = MP4_CONTAINERS.any? { |c| metadata[:container]&.include?(c) }
    normalize_audio = needs_audio_normalization?(metadata)

    if h264 && aac && mp4_container && !normalize_audio
      :none
    elsif h264 && aac && !normalize_audio
      :remux
    elsif h264
      :transcode_audio
    else
      :full
    end
  end

  def needs_audio_normalization?(metadata)
    return false unless metadata[:audio_channels]

    metadata[:audio_channels] > 2
  end

  def remux_to_mp4(input_path, output_path)
    success = system(
      "ffmpeg", "-y", "-i", input_path,
      "-c", "copy",
      "-movflags", "+faststart",
      output_path,
      out: File::NULL, err: File::NULL
    )
    raise "ffmpeg remux failed" unless success
  end

  def transcode_audio_to_mp4(input_path, output_path)
    success = system(
      "ffmpeg", "-y", "-i", input_path,
      "-c:v", "copy", "-ac", "2", "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      output_path,
      out: File::NULL, err: File::NULL
    )
    raise "ffmpeg audio transcode failed" unless success
  end

  def convert_to_mp4(input_path, output_path)
    success = system(
      "ffmpeg", "-y", "-i", input_path,
      "-c:v", "libx264", "-preset", "medium", "-crf", "23",
      "-ac", "2", "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      "-vf", "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease",
      output_path,
      out: File::NULL, err: File::NULL
    )
    raise "ffmpeg video conversion failed" unless success
  end

  def generate_thumbnail(input_path, thumbnail_path, duration)
    seek_time = duration ? (duration * 0.1).round(2) : 1
    system(
      "ffmpeg", "-y", "-i", input_path,
      "-ss", seek_time.to_s, "-vframes", "1",
      "-vf", "scale=640:-1",
      thumbnail_path,
      out: File::NULL, err: File::NULL
    )
  end
end
