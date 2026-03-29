module Maintenance
  class DeletePrivateVideoTracksTask < MaintenanceTasks::Task
    def collection
      Track.where(title: ["Private video", "Deleted video"])
    end

    def count
      collection.count
    end

    def process(track)
      track.destroy!
    end
  end
end
