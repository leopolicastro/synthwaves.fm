class API::V1::RadioStationControlsController < API::V1::BaseController
  ALLOWED_ACTIONS = %w[start stop skip].freeze

  before_action :set_station

  def create
    action = params[:action_name]

    unless ALLOWED_ACTIONS.include?(action)
      return render_error("action_name must be one of: #{ALLOWED_ACTIONS.join(", ")}")
    end

    case action
    when "start"
      start_station
    when "stop"
      stop_station
    when "skip"
      skip_track
    end
  end

  private

  def set_station
    @station = current_user.radio_stations.find(params[:radio_station_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def start_station
    @station.update!(status: "starting", error_message: nil)
    RadioQueueService.new(@station).populate!
    StationControlJob.perform_later(@station.id, "start")
    render json: {status: @station.status, message: "Station starting"}
  end

  def stop_station
    @station.update!(status: "stopped", current_track: nil)
    RadioQueueService.new(@station).clear!
    StationControlJob.perform_later(@station.id, "stop")
    render json: {status: @station.status, message: "Station stopped"}
  end

  def skip_track
    StationControlJob.perform_later(@station.id, "skip")
    render json: {status: @station.status, message: "Skipping track"}
  end
end
