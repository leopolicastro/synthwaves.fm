class API::Subsonic::PlaylistsController < API::Subsonic::BaseController
  def get_playlists
    playlists = current_user.playlists
    render_subsonic(playlists: {
      playlist: [all_tracks_virtual_entry, podcasts_virtual_entry] + playlists.map { |p| playlist_to_entry(p) }
    })
  end

  def get_playlist
    if params[:id] == "all"
      tracks = current_user.tracks.music.streamable.includes(:album, :artist).order(:title)
      render_subsonic(playlist: all_tracks_virtual_entry.merge(
        entry: tracks.map { |t| track_to_child(t) }
      ))
      return
    end

    if params[:id] == "podcasts"
      tracks = current_user.tracks.podcast.streamable.includes(:album, :artist).order(:title)
      render_subsonic(playlist: podcasts_virtual_entry.merge(
        entry: tracks.map { |t| track_to_child(t) }
      ))
      return
    end

    playlist = current_user.playlists.includes(playlist_tracks: {track: [:album, :artist, :audio_file_attachment]}).find(params[:id])
    render_subsonic(playlist: playlist_to_entry(playlist).merge(
      entry: playlist.playlist_tracks.order(:position).filter_map { |pt| track_to_child(pt.track) if pt.track.audio_file.attached? }
    ))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Playlist not found")
  end

  def create_playlist
    if params[:playlistId].in?(%w[all podcasts])
      render_subsonic_error(70, "Cannot modify a virtual playlist")
      return
    end

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
    if params[:id].in?(%w[all podcasts])
      render_subsonic_error(70, "Cannot delete a virtual playlist")
      return
    end

    playlist = current_user.playlists.find(params[:id])
    playlist.destroy!
    render_subsonic
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Playlist not found")
  end

  private

  def all_tracks_virtual_entry
    {
      id: "all",
      name: "All Tracks",
      songCount: current_user.tracks.music.streamable.count,
      duration: current_user.tracks.music.streamable.sum(:duration).to_i,
      owner: current_user.email_address,
      public: false
    }
  end

  def podcasts_virtual_entry
    {
      id: "podcasts",
      name: "Podcasts",
      songCount: current_user.tracks.podcast.streamable.count,
      duration: current_user.tracks.podcast.streamable.sum(:duration).to_i,
      owner: current_user.email_address,
      public: false
    }
  end

  def playlist_to_entry(playlist)
    {
      id: playlist.id.to_s,
      name: playlist.name,
      songCount: playlist.tracks.merge(Track.streamable).size,
      duration: playlist.tracks.merge(Track.streamable).sum(:duration).to_i,
      owner: current_user.email_address,
      public: false
    }
  end
end
