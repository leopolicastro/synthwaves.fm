class API::V1::PlaylistsController < API::V1::BaseController
  before_action :set_playlist, only: [:show, :update, :destroy]

  def index
    scope = current_user.playlists
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.order(sort_column(Playlist) => sort_direction)

    pagy, playlists = pagy(:offset, scope, limit: per_page)

    render json: {
      playlists: playlists.map { |p| playlist_json(p) },
      pagination: pagination_meta(pagy)
    }
  end

  def show
    scope = @playlist.playlist_tracks.includes(track: [:artist, :album]).order(:position)
    pagy, playlist_tracks = pagy(:offset, scope, limit: [(params[:per_page] || 50).to_i, 100].min)

    render json: playlist_json(@playlist).merge(
      total_duration: @playlist.tracks.sum(:duration),
      tracks: playlist_tracks.map { |pt| playlist_track_json(pt) },
      pagination: pagination_meta(pagy)
    )
  end

  def create
    playlist = current_user.playlists.build(playlist_params)

    if playlist.save
      add_tracks_if_present(playlist)
      render json: playlist_json(playlist), status: :created
    else
      render_validation_errors(playlist)
    end
  end

  def update
    if @playlist.update(playlist_params)
      render json: playlist_json(@playlist)
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

  def playlist_json(playlist)
    {
      id: playlist.id,
      name: playlist.name,
      tracks_count: playlist.playlist_tracks_count,
      created_at: playlist.created_at,
      updated_at: playlist.updated_at
    }
  end

  def playlist_track_json(pt)
    {
      position: pt.position,
      playlist_track_id: pt.id,
      track: {
        id: pt.track.id,
        title: pt.track.title,
        duration: pt.track.duration,
        artist: {id: pt.track.artist_id, name: pt.track.artist.name},
        album: {id: pt.track.album_id, title: pt.track.album.title}
      }
    }
  end
end
