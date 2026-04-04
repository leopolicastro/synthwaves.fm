module API
  module V1
    class PlaylistSerializer < Blueprinter::Base
      identifier :id

      view :ref do
        field :name
      end

      view :full do
        include_view :ref
        field :tracks_count do |playlist|
          playlist.playlist_tracks_count
        end
        fields :created_at, :updated_at
      end
    end
  end
end
