class API::Subsonic::PlaylistsController < API::Subsonic::BaseController
  def get_playlists
    playlists = current_user.playlists
    render_subsonic(playlists: {
      playlist: playlists.map { |p| playlist_to_entry(p) }
    })
  end

  def get_playlist
    playlist = current_user.playlists.includes(playlist_tracks: {track: [:album, :artist]}).find(params[:id])
    render_subsonic(playlist: playlist_to_entry(playlist).merge(
      entry: playlist.playlist_tracks.order(:position).map { |pt| track_to_child(pt.track) }
    ))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Playlist not found")
  end

  def create_playlist
    if params[:playlistId].present?
      playlist = current_user.playlists.find(params[:playlistId])
      playlist.update!(name: params[:name]) if params[:name].present?
    else
      playlist = current_user.playlists.create!(name: params[:name] || "New Playlist")
    end

    if params[:songId].present?
      song_ids = Array(params[:songId])
      playlist.playlist_tracks.destroy_all
      song_ids.each_with_index do |id, i|
        playlist.playlist_tracks.create!(track_id: id, position: i + 1)
      end
    end

    render_subsonic(playlist: playlist_to_entry(playlist))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Playlist not found")
  end

  def delete_playlist
    playlist = current_user.playlists.find(params[:id])
    playlist.destroy!
    render_subsonic
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Playlist not found")
  end

  private

  def playlist_to_entry(playlist)
    {
      id: playlist.id.to_s,
      name: playlist.name,
      songCount: playlist.tracks.size,
      duration: playlist.tracks.sum(:duration).to_i,
      owner: current_user.email_address,
      public: false
    }
  end
end
