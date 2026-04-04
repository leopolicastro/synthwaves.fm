module API
  module V1
    class ProfileSerializer
      def self.to_full(user)
        {
          id: user.id,
          name: user.name,
          email_address: user.email_address,
          theme: user.theme,
          created_at: user.created_at,
          stats: {
            artists_count: user.artists.count,
            albums_count: user.albums.count,
            tracks_count: user.tracks.count,
            playlists_count: user.playlists.count
          }
        }
      end
    end
  end
end
