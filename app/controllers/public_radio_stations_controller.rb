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

    respond_to do |format|
      format.html do
        if @station.active? || @station.idle?
          @upcoming_tracks = @station.upcoming_tracks(3)
          @recently_played = @station.recently_played_tracks(10)
        end
      end
      format.m3u { render plain: m3u_content, content_type: "audio/x-mpegurl" }
      format.pls { render plain: pls_content, content_type: "audio/x-scpls" }
      format.any { redirect_to @station.listen_url, allow_other_host: true, status: :found }
    end
  end

  private

  def m3u_content
    "#EXTM3U\n#EXTINF:-1,#{@station.playlist.name}\n#{@station.listen_url}\n"
  end

  def pls_content
    <<~PLS
      [playlist]
      NumberOfEntries=1
      File1=#{@station.listen_url}
      Title1=#{@station.playlist.name}
      Length1=-1
      Version=2
    PLS
  end
end
