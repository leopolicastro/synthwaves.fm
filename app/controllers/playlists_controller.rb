class PlaylistsController < ApplicationController
  include Orderable

  before_action :set_playlist, only: [:show, :edit, :update, :destroy, :merge]

  def index
    @query = params[:q]
    @sort = sort_column(Playlist, default: "created_at")
    @direction = sort_direction
    scope = Current.user.playlists.search(@query).order(@sort => @direction)
    @pagy, @playlists = pagy(:offset, scope)
    @cover_albums_by_playlist = Playlist.preload_cover_albums(@playlists)
  end

  def show
    @query = params[:q]
    @total_track_count = @playlist.playlist_tracks_count
    @total_duration = @playlist.tracks.sum(:duration)

    scope = @playlist.playlist_tracks.includes(track: [:artist, :album]).order(:position)
    if @query.present?
      track_ids = Track.search(@query).select(:id)
      scope = scope.where(track_id: track_ids)
    end

    @pagy, @playlist_tracks = pagy(:offset, scope, limit: 50)
    @favorited_track_ids = Current.user.favorited_ids_for("Track")
  end

  def new
    @playlist = Playlist.new
  end

  def create
    @playlist = Current.user.playlists.build(playlist_params)
    if @playlist.save
      add_tracks_if_present
      redirect_to @playlist, notice: "Playlist created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to @playlist, notice: "Playlist updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def merge
    source = Current.user.playlists.find(params[:source_playlist_id])
    PlaylistMergeService.call(target: @playlist, source: source)
    redirect_to @playlist, notice: "Merged \"#{source.name}\" into this playlist."
  rescue PlaylistMergeService::Error => e
    redirect_to @playlist, alert: e.message
  rescue ActiveRecord::RecordNotFound
    redirect_to @playlist, alert: "Source playlist not found."
  end

  def destroy
    @playlist.destroy
    redirect_to playlists_path, notice: "Playlist deleted."
  end

  private

  def set_playlist
    @playlist = Current.user.playlists.find(params[:id])
  end

  def add_tracks_if_present
    return unless params[:track_ids].present?

    tracks = Track.where(id: params[:track_ids])
    ordered = params[:track_ids].map(&:to_i).filter_map { |id| tracks.find { |t| t.id == id } }
    @playlist.add_tracks(ordered)
  end

  def playlist_params
    params.require(:playlist).permit(:name)
  end
end
