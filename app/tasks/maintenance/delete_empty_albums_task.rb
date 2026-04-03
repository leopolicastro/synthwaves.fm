module Maintenance
  class DeleteEmptyAlbumsTask < MaintenanceTasks::Task
    def collection
      Album.where.missing(:tracks)
    end

    def count
      collection.count
    end

    def process(album)
      album.destroy!
    end
  end
end
