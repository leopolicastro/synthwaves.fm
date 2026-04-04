module API
  module V1
    class PlaylistSerializer
      def self.to_full(playlist)
        {
          id: playlist.id,
          name: playlist.name,
          tracks_count: playlist.playlist_tracks_count,
          created_at: playlist.created_at,
          updated_at: playlist.updated_at
        }
      end

      def self.to_ref(playlist)
        {
          id: playlist.id,
          name: playlist.name
        }
      end
    end
  end
end
