class RadioStationBroadcaster
  def self.status(station)
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_stations_#{station.user_id}",
      target: "radio_station_#{station.id}",
      partial: "radio_stations/station",
      locals: {station: station}
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_station_public_#{station.id}",
      target: "public_status_#{station.id}",
      partial: "radio_stations/status_badge",
      locals: {station: station}
    )
  end

  def self.now_playing(station)
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_stations_#{station.user_id}",
      target: "now_playing_#{station.id}",
      partial: "radio_stations/now_playing",
      locals: {station: station}
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_station_public_#{station.id}",
      target: "now_playing_#{station.id}",
      partial: "radio_stations/now_playing",
      locals: {station: station}
    )
  end

  def self.queue(station)
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_station_public_#{station.id}",
      target: "station_queue_#{station.id}",
      partial: "public_radio_stations/queue",
      locals: {station: station, upcoming_tracks: station.upcoming_tracks, recently_played: station.recently_played_tracks}
    )
  end
end
