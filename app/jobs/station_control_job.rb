class StationControlJob < ApplicationJob
  def perform(station_id, action)
    return unless Flipper.enabled?(:radio_stations)

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
    return unless Rails.env.production?

    socket = UNIXSocket.new("/var/run/docker.sock")
    request = "POST /containers/synthwaves_fm-liquidsoap/restart HTTP/1.0\r\nHost: localhost\r\n\r\n"
    socket.write(request)
    response = socket.read
    socket.close

    status = response[/HTTP\/\d\.\d (\d+)/, 1].to_i
    unless status == 204
      Rails.logger.warn("Failed to restart Liquidsoap container: HTTP #{status}")
    end
  rescue => e
    Rails.logger.warn("Failed to restart Liquidsoap container: #{e.message}")
  end
end
