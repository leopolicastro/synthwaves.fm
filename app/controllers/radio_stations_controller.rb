class RadioStationsController < ApplicationController
  before_action :set_station, only: [:show, :edit, :update, :destroy, :start, :stop, :skip]

  def index
    @stations = Current.user.radio_stations.includes(:playlist, current_track: [:artist, {album: {cover_image_attachment: :blob}}]).order(created_at: :desc)
  end

  def show
  end

  def create
    playlist = Current.user.playlists.find(params[:playlist_id])
    @station = Current.user.radio_stations.build(playlist: playlist)

    if @station.save
      redirect_to @station, notice: "Radio station created."
    else
      redirect_to playlist_path(playlist), alert: @station.errors.full_messages.join(", ")
    end
  end

  def edit
  end

  def update
    if @station.update(station_params)
      if @station.saved_change_to_playback_mode? && !@station.stopped?
        RadioQueueService.new(@station).populate!
      end
      redirect_to @station, notice: "Station updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def start
    @station.update!(status: "starting", started_at: Time.current, error_message: nil)
    RadioQueueService.new(@station).populate!
    StationControlJob.perform_later(@station.id, "start")
    redirect_to @station, notice: "Station starting..."
  end

  def stop
    @station.update!(status: "stopped", current_track: nil)
    RadioQueueService.new(@station).clear!
    StationControlJob.perform_later(@station.id, "stop")
    redirect_to @station, notice: "Station stopped."
  end

  def skip
    StationControlJob.perform_later(@station.id, "skip")
    redirect_to @station, notice: "Skipping track..."
  end

  def destroy
    StationControlJob.perform_later(@station.id, "stop") if @station.active? || @station.idle? || @station.starting?
    @station.destroy
    redirect_to radio_stations_path, notice: "Station removed."
  end

  private

  def set_station
    @station = Current.user.radio_stations.find(params[:id])
  end

  def station_params
    params.require(:radio_station).permit(:playback_mode, :bitrate, :crossfade, :crossfade_duration, :favorites_weight, :image)
  end
end
