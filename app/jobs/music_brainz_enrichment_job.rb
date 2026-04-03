class MusicBrainzEnrichmentJob < ApplicationJob
  queue_as :default

  retry_on MusicBrainzService::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(track_id)
    track = Track.find(track_id)
    MusicBrainzEnricherService.call(track)
  end
end
