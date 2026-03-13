class API::Subsonic::MediaController < API::Subsonic::BaseController
  def stream
    track = current_user.tracks.find(params[:id])
    if track.audio_file.attached?
      redirect_to Rails.application.routes.url_helpers.rails_blob_url(track.audio_file, host: request.host_with_port, protocol: request.scheme), allow_other_host: true
    else
      render_subsonic_error(70, "Song not found")
    end
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Song not found")
  end

  alias_method :download, :stream

  def get_cover_art
    album = current_user.albums.find(params[:id])
    if album.cover_image.attached?
      redirect_to Rails.application.routes.url_helpers.rails_blob_url(album.cover_image, host: request.host_with_port, protocol: request.scheme), allow_other_host: true
    else
      head :not_found
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
