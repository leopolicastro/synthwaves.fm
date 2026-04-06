class API::V1::PublicRadioStationsController < API::V1::BaseController

  def index
    stations = RadioStation
      .includes(:playlist, :image_attachment, current_track: [:artist, {album: {cover_image_attachment: :blob}}])
      .where.not(status: "stopped")
      .order(listener_count: :desc, started_at: :desc)

    render json: {
      radio_stations: API::V1::PublicRadioStationSerializer.render_as_hash(stations)
    }
  end

  def show
    station = RadioStation.includes(:playlist, :image_attachment, current_track: [:artist, {album: {cover_image_attachment: :blob}}]).find_by_slug!(params[:slug])

    render json: API::V1::PublicRadioStationSerializer.render_as_hash(station)
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
