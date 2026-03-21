module Maintenance
  class NormalizeSurroundAudioTask < MaintenanceTasks::Task
    def collection
      Video.ready.where("audio_channels > 2 OR audio_channels IS NULL")
    end

    def count
      collection.count
    end

    def process(video)
      return unless video.file.attached?

      video.file.open do |source_file|
        metadata = VideoMetadataExtractor.call(source_file.path)
        channels = metadata[:audio_channels]

        video.update!(audio_channels: channels)
        return nil unless channels && channels > 2

        output_path = "#{source_file.path}.normalized.mp4"

        success = system(
          "ffmpeg", "-y", "-i", source_file.path,
          "-c:v", "copy", "-ac", "2", "-c:a", "aac", "-b:a", "128k",
          "-movflags", "+faststart",
          output_path,
          out: File::NULL, err: File::NULL
        )
        raise "ffmpeg surround normalization failed for video #{video.id}" unless success

        video.file.attach(
          io: File.open(output_path),
          filename: video.file.filename.to_s.sub(/\.\w+$/, ".mp4"),
          content_type: "video/mp4"
        )

        final_metadata = VideoMetadataExtractor.call(output_path)

        video.update!(
          audio_channels: final_metadata[:audio_channels],
          audio_codec: final_metadata[:audio_codec] || video.audio_codec,
          bitrate: final_metadata[:bitrate] || video.bitrate,
          file_size: File.size(output_path)
        )
      ensure
        FileUtils.rm_f(output_path) if output_path
      end
    end
  end
end
