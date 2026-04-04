class API::V1::RadioStationsController < API::V1::BaseController
  before_action :set_station, only: [:show, :update, :destroy]

  def index
    stations = current_user.radio_stations
      .includes(:playlist, current_track: [:artist])
      .order(created_at: :desc)

    render json: {
      radio_stations: API::V1::RadioStationSerializer.render_as_hash(stations)
    }
  end

  def show
    render json: API::V1::RadioStationSerializer.render_as_hash(@station)
  end

  def create
    playlist = current_user.playlists.find(params[:playlist_id])
    station = current_user.radio_stations.build(playlist: playlist)

    if station.save
      render json: API::V1::RadioStationSerializer.render_as_hash(station), status: :created
    else
      render_validation_errors(station)
    end
  rescue ActiveRecord::RecordNotFound
    render_error("Playlist not found", status: :not_found)
  end

  def update
    if @station.update(station_params)
      if @station.saved_change_to_playback_mode? && !@station.stopped?
        RadioQueueService.new(@station).populate!
      end
      render json: API::V1::RadioStationSerializer.render_as_hash(@station)
    else
      render_validation_errors(@station)
    end
  end

  def destroy
    StationControlJob.perform_later(@station.id, "stop") if @station.active? || @station.idle? || @station.starting?
    @station.destroy
    head :no_content
  end

  private

  def set_station
    @station = current_user.radio_stations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def station_params
    params.require(:radio_station).permit(:playback_mode, :bitrate, :crossfade_duration)
  end
end
