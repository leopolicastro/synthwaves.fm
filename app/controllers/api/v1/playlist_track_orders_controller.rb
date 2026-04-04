class API::V1::PlaylistTrackOrdersController < API::V1::BaseController
  before_action :set_playlist

  def update
    ids = params[:playlist_track_ids]

    unless ids.is_a?(Array) && ids.any?
      return render_error("playlist_track_ids array required")
    end

    ActiveRecord::Base.transaction do
      # Use negative positions to avoid unique constraint violations during reorder
      ids.each_with_index do |id, index|
        @playlist.playlist_tracks.where(id: id).update_all(position: -(index + 1))
      end
      ids.each_with_index do |id, index|
        @playlist.playlist_tracks.where(id: id).update_all(position: index + 1)
      end
    end

    render json: {reordered: ids.size}
  end

  private

  def set_playlist
    @playlist = current_user.playlists.find(params[:playlist_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
