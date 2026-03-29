class AudioConversionJob < ApplicationJob
  queue_as :conversion

  CONVERTIBLE_FORMATS = %w[webm ogg wav flac aac wma].freeze

  def perform(track_id)
    track = Track.find(track_id)
    return unless track.audio_file.attached?
    return unless CONVERTIBLE_FORMATS.include?(track.file_format)

    track.audio_file.open do |source_file|
      output_path = "#{source_file.path}.mp3"

      convert_to_mp3(source_file.path, output_path)

      track.audio_file.attach(
        io: File.open(output_path),
        filename: track.audio_file.filename.to_s.sub(/\.\w+$/, ".mp3"),
        content_type: "audio/mpeg"
      )

      metadata = begin
        MetadataExtractor.call(output_path)
      rescue WahWah::WahWahArgumentError
        {}
      end
      duration = metadata[:duration] || probe_duration(output_path)

      track.update!(
        title: metadata[:title] || track.title,
        track_number: metadata[:track_number] || track.track_number,
        disc_number: metadata[:disc_number] || track.disc_number,
        bitrate: metadata[:bitrate] || track.bitrate,
        file_format: "mp3",
        file_size: File.size(output_path),
        duration: duration || track.duration
      )

      update_album_metadata(track, metadata)
    ensure
      FileUtils.rm_f(output_path) if output_path
    end
  end

  private

  def convert_to_mp3(input_path, output_path)
    success = system(
      "ffmpeg", "-y", "-i", input_path,
      "-codec:a", "libmp3lame", "-b:a", "192k",
      output_path,
      out: File::NULL, err: File::NULL
    )

    raise "ffmpeg conversion failed" unless success
  end

  def probe_duration(path)
    output = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 #{Shellwords.escape(path)} 2>/dev/null`.strip
    output.present? ? output.to_f : nil
  end

  def update_album_metadata(track, metadata)
    album = track.album

    if metadata[:artist].present? && track.artist.name == "Unknown Artist"
      artist = track.user.artists.find_or_create_by!(name: metadata[:artist])
      track.update!(artist: artist)
    end

    if metadata[:album].present? && album.title.in?(["Unknown Album", YoutubeVideoImportService::SINGLES_ALBUM_TITLE])
      album.update!(title: metadata[:album])
    end

    if metadata[:cover_art] && !album.cover_image.attached?
      album.cover_image.attach(
        io: StringIO.new(metadata[:cover_art][:data]),
        filename: "cover.jpg",
        content_type: metadata[:cover_art][:mime_type] || "image/jpeg"
      )
    end
  end
end
