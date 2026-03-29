class PublicRadioStationsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  layout "landing"

  def index
    @stations = RadioStation.includes(:playlist, :current_track, image_attachment: :blob, current_track: {album: {cover_image_attachment: :blob}})
      .where.not(status: "stopped")
      .order(listener_count: :desc, started_at: :desc)
  end

  def show
    @station = RadioStation.find_by_slug!(params[:slug])
  end
end
