module API
  module V1
    class ArtistSerializer < Blueprinter::Base
      identifier :id

      view :ref do
        field :name
      end

      view :summary do
        include_view :ref
        field :category
      end

      view :full do
        include_view :summary
        field :image_url
        field :albums_count do |artist|
          artist.albums.size
        end
        field :tracks_count do |artist|
          artist.tracks.size
        end
        field :created_at
      end
    end
  end
end
