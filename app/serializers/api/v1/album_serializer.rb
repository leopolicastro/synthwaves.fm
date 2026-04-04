module API
  module V1
    class AlbumSerializer
      def self.to_full(album)
        {
          id: album.id,
          title: album.title,
          year: album.year,
          genre: album.genre,
          artist: ArtistSerializer.to_ref(album.artist),
          tracks_count: album.tracks.size,
          cover_image_url: cover_image_url(album),
          created_at: album.created_at
        }
      end

      def self.to_summary(album)
        {
          id: album.id,
          title: album.title,
          year: album.year,
          genre: album.genre,
          tracks_count: album.tracks.size,
          cover_image_url: cover_image_url(album)
        }
      end

      def self.to_ref(album)
        {
          id: album.id,
          title: album.title
        }
      end

      def self.to_search_result(album)
        {
          id: album.id,
          title: album.title,
          year: album.year,
          genre: album.genre,
          artist: ArtistSerializer.to_ref(album.artist)
        }
      end

      def self.cover_image_url(album)
        return nil unless album.cover_image.attached?
        Rails.application.routes.url_helpers.url_for(album.cover_image)
      end

      private_class_method :cover_image_url
    end
  end
end
