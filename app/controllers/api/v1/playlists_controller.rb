class API::V1::PlaylistsController < API::V1::BaseController
  before_action :set_playlist, only: [:show, :update, :destroy]

  def index
    scope = current_user.playlists
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.order(sort_column(Playlist) => sort_direction)

    pagy, playlists = pagy(:offset, scope, limit: per_page)

    render json: {
      playlists: API::V1::PlaylistSerializer.render_as_hash(playlists, view: :full),
      pagination: pagination_meta(pagy)
    }
  end

  def show
    scope = @playlist.playlist_tracks.includes(track: [:artist, :album]).order(:position)
    pagy, playlist_tracks = pagy(:offset, scope, limit: [(params[:per_page] || 50).to_i, 100].min)

    render json: API::V1::PlaylistSerializer.render_as_hash(@playlist, view: :full).merge(
      total_duration: @playlist.tracks.sum(:duration),
      tracks: API::V1::PlaylistTrackSerializer.render_as_hash(playlist_tracks),
      pagination: pagination_meta(pagy)
    )
  end

  def create
    playlist = current_user.playlists.build(playlist_params)

    if playlist.save
      add_tracks_if_present(playlist)
      render json: API::V1::PlaylistSerializer.render_as_hash(playlist, view: :full), status: :created
    else
      render_validation_errors(playlist)
    end
  end

  def update
    if @playlist.update(playlist_params)
      render json: API::V1::PlaylistSerializer.render_as_hash(@playlist, view: :full)
    else
      render_validation_errors(@playlist)
    end
  end

  def destroy
    @playlist.destroy
    head :no_content
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def playlist_params
    params.require(:playlist).permit(:name)
  end

  def add_tracks_if_present(playlist)
    return unless params[:track_ids].present?

    tracks = current_user.tracks.where(id: params[:track_ids])
    ordered = params[:track_ids].map(&:to_i).filter_map { |id| tracks.find { |t| t.id == id } }
    playlist.add_tracks(ordered)
  end
end
