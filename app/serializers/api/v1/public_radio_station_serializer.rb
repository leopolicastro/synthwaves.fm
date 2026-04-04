module API
  module V1
    class PublicRadioStationSerializer < Blueprinter::Base
      identifier :id

      field :name do |station|
        station.playlist.name
      end

      fields :status, :slug, :listen_url, :listener_count

      field :image_url do |station|
        image = station.display_image
        if image&.attached?
          Rails.application.routes.url_helpers.url_for(image)
        end
      end

      field :current_track do |station|
        if station.current_track
          TrackSerializer.render_as_hash(station.current_track, view: :minimal)
        end
      end
    end
  end
end
