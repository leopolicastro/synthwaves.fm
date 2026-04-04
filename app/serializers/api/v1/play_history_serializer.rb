module API
  module V1
    class PlayHistorySerializer
      def self.to_full(history)
        {
          id: history.id,
          track: TrackSerializer.to_embedded(history.track),
          played_at: history.played_at
        }
      end
    end
  end
end
