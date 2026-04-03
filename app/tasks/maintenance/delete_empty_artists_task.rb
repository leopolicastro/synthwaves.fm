module Maintenance
  class DeleteEmptyArtistsTask < MaintenanceTasks::Task
    def collection
      Artist.where.missing(:albums).where.missing(:tracks)
    end

    def count
      collection.count
    end

    def process(artist)
      artist.destroy!
    end
  end
end
