class MetadataExtractionJob < ApplicationJob
  queue_as :default

  def perform(track_id)
    track = Track.find(track_id)
    return unless track.audio_file.attached?

    track.audio_file.open do |tempfile|
      metadata = MetadataExtractor.call(tempfile.path)

      track.update!(
        title: metadata[:title] || track.title,
        track_number: metadata[:track_number] || track.track_number,
        disc_number: metadata[:disc_number] || track.disc_number,
        duration: metadata[:duration] || track.duration,
        bitrate: metadata[:bitrate] || track.bitrate
      )

      if metadata[:cover_art] && !track.album.cover_image.attached?
        track.album.cover_image.attach(
          io: StringIO.new(metadata[:cover_art][:data]),
          filename: "cover.jpg",
          content_type: metadata[:cover_art][:mime_type] || "image/jpeg"
        )
      end
    end
  end
end
