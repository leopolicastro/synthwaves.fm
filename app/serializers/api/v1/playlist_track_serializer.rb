module API
  module V1
    class PlaylistTrackSerializer < Blueprinter::Base
      field :position
      field :playlist_track_id do |pt|
        pt.id
      end
      association :track, blueprint: TrackSerializer, view: :embedded
    end
  end
end
