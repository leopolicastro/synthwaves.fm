class API::V1::PlaylistTracksController < API::V1::BaseController
  before_action :set_playlist

  def create
    if params[:track_ids].present?
      add_multiple_tracks
    elsif params[:album_id].present?
      add_album_tracks
    elsif params[:track_id].present?
      add_single_track
    else
      render_error("track_id, track_ids, or album_id required")
    end
  end

  def destroy
    playlist_track = @playlist.playlist_tracks.find(params[:id])
    playlist_track.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:playlist_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def add_single_track
    track = current_user.tracks.find(params[:track_id])
    pt = @playlist.add_track(track)

    if pt
      render json: {added: 1, tracks_count: @playlist.reload.playlist_tracks_count}, status: :created
    else
      render json: {added: 0, tracks_count: @playlist.playlist_tracks_count}, status: :ok
    end
  rescue ActiveRecord::RecordNotFound
    render_error("Track not found", status: :not_found)
  end

  def add_multiple_tracks
    tracks = current_user.tracks.where(id: params[:track_ids])
    ordered = params[:track_ids].map(&:to_i).filter_map { |id| tracks.find { |t| t.id == id } }
    added = @playlist.add_tracks(ordered)

    render json: {added: added, tracks_count: @playlist.reload.playlist_tracks_count}, status: :created
  end

  def add_album_tracks
    album = current_user.albums.find(params[:album_id])
    added = @playlist.add_tracks(album.tracks.order(:disc_number, :track_number))

    render json: {added: added, tracks_count: @playlist.reload.playlist_tracks_count}, status: :created
  rescue ActiveRecord::RecordNotFound
    render_error("Album not found", status: :not_found)
  end
end
