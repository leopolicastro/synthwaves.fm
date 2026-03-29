module Maintenance
  class AppleMusicBulkEnrichmentTask < MaintenanceTasks::Task
    def collection
      Track.music.where(enrichment_status: [nil, "failed"])
    end

    def count
      collection.count
    end

    def process(track)
      @index ||= 0
      AppleMusicEnrichmentJob.set(wait: @index * 2.seconds).perform_later(track.id)
      @index += 1
    end
  end
end
