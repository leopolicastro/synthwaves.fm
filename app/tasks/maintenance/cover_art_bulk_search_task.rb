module Maintenance
  class CoverArtBulkSearchTask < MaintenanceTasks::Task
    def collection
      Album.where.missing(:cover_image_attachment)
    end

    def count
      collection.count
    end

    def process(album)
      @index ||= 0
      CoverArtSearchJob.set(wait: @index * 3.seconds).perform_later(album)
      @index += 1
    end
  end
end
