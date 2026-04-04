module API
  module V1
    class PlaylistTrackSerializer
      def self.to_full(playlist_track)
        {
          position: playlist_track.position,
          playlist_track_id: playlist_track.id,
          track: TrackSerializer.to_embedded(playlist_track.track)
        }
      end
    end
  end
end
