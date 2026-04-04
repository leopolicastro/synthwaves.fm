class API::V1::ProfileController < API::V1::BaseController
  def show
    render json: profile_json
  end

  def update
    if current_user.update(profile_params)
      render json: profile_json
    else
      render_validation_errors(current_user)
    end
  end

  private

  def profile_json
    {
      id: current_user.id,
      name: current_user.name,
      email_address: current_user.email_address,
      theme: current_user.theme,
      created_at: current_user.created_at,
      stats: {
        artists_count: current_user.artists.count,
        albums_count: current_user.albums.count,
        tracks_count: current_user.tracks.count,
        playlists_count: current_user.playlists.count
      }
    }
  end

  def profile_params
    params.permit(:name, :theme)
  end
end
