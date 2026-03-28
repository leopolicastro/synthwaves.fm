class API::Subsonic::RadioController < API::Subsonic::BaseController
  def get_internet_radio_stations
    stations = []

    # Playlist-based radio stations (Icecast streams)
    if Flipper.enabled?(:radio_stations, current_user)
      current_user.radio_stations.where.not(status: "stopped").each do |station|
        stations << {
          id: "radio-#{station.id}",
          name: station.playlist.name,
          streamUrl: station.listen_url,
          homePageUrl: ""
        }
      end
    end

    # Stream-type external streams
    current_user.external_streams.where(source_type: "stream").each do |stream|
      stations << {
        id: "stream-#{stream.id}",
        name: stream.name,
        streamUrl: stream.stream_url,
        homePageUrl: stream.original_url || ""
      }
    end

    render_subsonic(
      internetRadioStations: {
        internetRadioStation: stations
      }
    )
  end
end
