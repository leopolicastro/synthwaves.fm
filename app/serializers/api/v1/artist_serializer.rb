module API
  module V1
    class ArtistSerializer
      def self.to_full(artist)
        {
          id: artist.id,
          name: artist.name,
          category: artist.category,
          image_url: artist.image_url,
          albums_count: artist.albums.size,
          tracks_count: artist.tracks.size,
          created_at: artist.created_at
        }
      end

      def self.to_summary(artist)
        {
          id: artist.id,
          name: artist.name,
          category: artist.category
        }
      end

      def self.to_ref(artist)
        {
          id: artist.id,
          name: artist.name
        }
      end
    end
  end
end
