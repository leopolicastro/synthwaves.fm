class API::Import::PlaylistsController < API::Import::BaseController
  def create
    name = params[:name]

    if name.blank?
      render json: { error: "name is required" }, status: :unprocessable_entity
      return
    end

    if current_user.playlists.exists?(name: name)
      render json: { error: "Playlist '#{name}' already exists" }, status: :conflict
      return
    end

    playlist = current_user.playlists.create!(name: name)

    not_found = []
    position = 0

    Array(params[:tracks]).each do |track_params|
      track = current_user.tracks.joins(:artist, :album)
        .where("LOWER(tracks.title) = ?", track_params[:title].to_s.downcase)
        .where("LOWER(artists.name) = ?", track_params[:artist].to_s.downcase)
        .where("LOWER(albums.title) = ?", track_params[:album].to_s.downcase)
        .first

      if track
        position += 1
        playlist.playlist_tracks.create!(track: track, position: position)
      else
        not_found << {
          title: track_params[:title],
          artist: track_params[:artist],
          album: track_params[:album]
        }
      end
    end

    render json: {
      id: playlist.id,
      name: playlist.name,
      tracks_matched: position,
      tracks_not_found: not_found.size,
      not_found: not_found
    }, status: :created
  end
end
