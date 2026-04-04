module API
  module V1
    class PlayHistorySerializer < Blueprinter::Base
      identifier :id

      association :track, blueprint: TrackSerializer, view: :embedded
      field :played_at
    end
  end
end
