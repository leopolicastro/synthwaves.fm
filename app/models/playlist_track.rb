class PlaylistTrack < ApplicationRecord
  belongs_to :playlist, counter_cache: true
  belongs_to :track

  after_destroy_commit :sync_active_station_queue

  private

  def sync_active_station_queue
    station = playlist.radio_station
    return unless station && !station.stopped?

    RadioQueueService.new(station).sync_with_playlist!
  end
end
