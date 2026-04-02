module Maintenance
  class MusicbrainzBulkEnrichmentTask < MaintenanceTasks::Task
    def collection
      Track.music.where(musicbrainz_enrichment_status: [nil, "failed"])
    end

    def count
      collection.count
    end

    def process(track)
      @index ||= 0
      MusicBrainzEnrichmentJob.set(wait: @index * 3.seconds).perform_later(track.id)
      @index += 1
    end
  end
end
