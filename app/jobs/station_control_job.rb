class StationControlJob < ApplicationJob
  def perform(station_id, action)
    station = RadioStation.find_by(id: station_id)
    return unless station

    case action
    when "start"
      start_station(station)
    when "stop"
      stop_station(station)
    when "skip"
      skip_track(station)
    end
  end

  private

  def start_station(station)
    LiquidsoapConfigService.call
    restart_liquidsoap
    station.update!(status: "active") if station.starting?
    station.broadcast_status
  rescue => e
    station.update!(status: "error", error_message: e.message)
    station.broadcast_status
  end

  def stop_station(station)
    station.update!(status: "stopped")
    LiquidsoapConfigService.call
    restart_liquidsoap
    station.broadcast_status
  rescue => e
    Rails.logger.error("Failed to stop station #{station.id}: #{e.message}")
  end

  def skip_track(station)
    return unless station.active? || station.idle?
    NextTrackService.call(station)
    station.broadcast_status
  end

  def restart_liquidsoap
    # In production, restart the Liquidsoap container via Kamal
    # This is a no-op in development/test
    return unless Rails.env.production?

    system("kamal accessory restart liquidsoap") ||
      Rails.logger.warn("Failed to restart Liquidsoap container")
  end
end
