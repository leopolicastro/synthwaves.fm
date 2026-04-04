module API
  module V1
    class FavoriteSerializer
      def self.to_full(favorite)
        {
          id: favorite.id,
          favorable_type: favorite.favorable_type,
          favorable_id: favorite.favorable_id,
          favorable: favorable_summary(favorite.favorable),
          created_at: favorite.created_at
        }
      end

      def self.favorable_summary(favorable)
        case favorable
        when Track
          {id: favorable.id, title: favorable.title, artist: {name: favorable.artist.name}}
        when Album
          {id: favorable.id, title: favorable.title, artist: {name: favorable.artist.name}}
        when Artist
          ArtistSerializer.to_ref(favorable)
        end
      end

      private_class_method :favorable_summary
    end
  end
end
