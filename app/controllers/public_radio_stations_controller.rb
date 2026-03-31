class PublicRadioStationsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  layout "landing"

  def index
    @stations = RadioStation.includes(:playlist, image_attachment: :blob, current_track: [:artist, {album: {cover_image_attachment: :blob}}])
      .where.not(status: "stopped")
      .order(listener_count: :desc, started_at: :desc)
  end

  def show
    @station = RadioStation.find_by_slug!(params[:slug])
    if @station.active? || @station.idle?
      @upcoming_tracks = @station.upcoming_tracks(3)
      @recently_played = @station.recently_played_tracks(10)
    end
  end
end
