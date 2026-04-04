class API::V1::PublicRadioStationsController < API::V1::BaseController
  skip_before_action :authenticate_with_jwt!

  def index
    stations = RadioStation
      .includes(:playlist, current_track: [:artist])
      .where.not(status: "stopped")
      .order(listener_count: :desc, started_at: :desc)

    render json: {
      radio_stations: API::V1::PublicRadioStationSerializer.render_as_hash(stations)
    }
  end

  def show
    station = RadioStation.includes(:playlist, current_track: [:artist]).find_by_slug!(params[:slug])

    render json: API::V1::PublicRadioStationSerializer.render_as_hash(station)
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
