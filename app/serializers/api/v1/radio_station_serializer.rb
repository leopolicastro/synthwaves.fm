module API
  module V1
    class RadioStationSerializer < Blueprinter::Base
      identifier :id

      field :name do |station|
        station.playlist.name
      end

      fields :status, :mount_point, :playback_mode, :bitrate,
        :crossfade_duration, :created_at

      field :listen_url do |station|
        station.listen_url
      end

      association :playlist, blueprint: PlaylistSerializer, view: :ref

      field :current_track do |station|
        if station.current_track
          TrackSerializer.render_as_hash(station.current_track, view: :minimal)
        end
      end
    end
  end
end
