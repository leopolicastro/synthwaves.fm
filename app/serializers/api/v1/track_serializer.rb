module API
  module V1
    class TrackSerializer
      def self.to_full(track)
        {
          id: track.id,
          title: track.title,
          track_number: track.track_number,
          disc_number: track.disc_number,
          duration: track.duration,
          bitrate: track.bitrate,
          file_format: track.file_format,
          file_size: track.file_size,
          lyrics: track.lyrics,
          has_audio: track.audio_file.attached?,
          artist: ArtistSerializer.to_ref(track.artist),
          album: AlbumSerializer.to_ref(track.album),
          created_at: track.created_at
        }
      end

      def self.to_summary(track)
        {
          id: track.id,
          title: track.title,
          track_number: track.track_number,
          disc_number: track.disc_number,
          duration: track.duration,
          file_format: track.file_format,
          has_audio: track.audio_file.attached?
        }
      end

      def self.to_embedded(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          artist: ArtistSerializer.to_ref(track.artist),
          album: AlbumSerializer.to_ref(track.album)
        }
      end

      def self.to_minimal(track)
        {
          id: track.id,
          title: track.title,
          artist: {name: track.artist.name}
        }
      end
    end
  end
end
