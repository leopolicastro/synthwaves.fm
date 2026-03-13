class API::Subsonic::VideoController < API::Subsonic::BaseController
  def get_videos
    videos = current_user.videos.ready.includes(:folder)
    videos = videos.where(folder_id: params[:folderId]) if params[:folderId].present?
    videos = videos.search(params[:query]) if params[:query].present?

    render_subsonic(videos: {video: videos.map { |v| video_to_entry(v) }})
  end

  def get_video
    video = current_user.videos.find(params[:id])
    render_subsonic(video: video_to_entry(video))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def stream
    video = current_user.videos.ready.find(params[:id])
    if video.file.attached?
      redirect_to rails_blob_url(video.file), allow_other_host: true
    else
      render_subsonic_error(70, "Video not found")
    end
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def get_thumbnail
    video = current_user.videos.find(params[:id])
    if video.thumbnail.attached?
      if params[:size].present?
        variant = video.thumbnail.variant(resize_to_fill: [params[:size].to_i, params[:size].to_i])
        redirect_to rails_representation_url(variant), allow_other_host: true
      else
        redirect_to rails_blob_url(video.thumbnail), allow_other_host: true
      end
    else
      head :not_found
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def save_playback_position
    video = current_user.videos.find(params[:id])
    position = current_user.video_playback_positions.find_or_initialize_by(video: video)
    position.position = params[:position].to_f
    position.save!

    render_subsonic
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def get_playback_position
    video = current_user.videos.find(params[:id])
    position = current_user.video_playback_positions.find_by(video: video)

    render_subsonic(playbackPosition: {id: video.id.to_s, position: position&.position || 0})
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Video not found")
  end

  def get_folders
    folders = current_user.folders.includes(:videos)
    folder_entries = folders.map do |folder|
      {
        id: folder.id.to_s,
        name: folder.name,
        videoCount: folder.videos.ready.size
      }
    end

    render_subsonic(folders: {folder: folder_entries})
  end

  def get_folder
    folder = current_user.folders.find(params[:id])
    videos = folder.videos.ready.ordered

    render_subsonic(
      folder: {
        id: folder.id.to_s,
        name: folder.name,
        video: videos.map { |v| video_to_entry(v) }
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Folder not found")
  end

  private

  def rails_blob_url(blob)
    Rails.application.routes.url_helpers.rails_blob_url(
      blob, host: request.host_with_port, protocol: request.scheme
    )
  end

  def rails_representation_url(variant)
    Rails.application.routes.url_helpers.rails_representation_url(
      variant, host: request.host_with_port, protocol: request.scheme
    )
  end
end
