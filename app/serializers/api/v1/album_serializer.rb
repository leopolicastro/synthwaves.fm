module API
  module V1
    class AlbumSerializer < Blueprinter::Base
      identifier :id

      view :ref do
        field :title
      end

      view :search_result do
        include_view :ref
        fields :year, :genre
        association :artist, blueprint: ArtistSerializer, view: :ref
      end

      view :summary do
        include_view :ref
        fields :year, :genre
        field :tracks_count do |album|
          album.tracks.size
        end
        field :cover_image_url do |album|
          if album.cover_image.attached?
            Rails.application.routes.url_helpers.url_for(album.cover_image)
          end
        end
      end

      view :full do
        include_view :summary
        association :artist, blueprint: ArtistSerializer, view: :ref
        field :created_at
      end
    end
  end
end
