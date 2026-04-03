module Maintenance
  class MusicBrainzReassociationTask < MaintenanceTasks::Task
    def collection
      Track.music.where(musicbrainz_enrichment_status: "matched")
    end

    def count
      collection.count
    end

    def process(track)
      @index ||= 0
      track.update!(musicbrainz_enrichment_status: nil, musicbrainz_enriched_at: nil)
      MusicBrainzEnrichmentJob.set(wait: @index * 3.seconds).perform_later(track.id)
      @index += 1
    end
  end
end
