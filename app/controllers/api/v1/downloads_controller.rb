class API::V1::DownloadsController < API::V1::BaseController
  def create
    if params[:url].present?
      song_download = TrafiClient.download_url(params[:url], user: current_user)
    elsif params[:query].present?
      song_download = TrafiClient.download_search(params[:query], user: current_user)
    else
      return render_error("url or query is required", status: :unprocessable_entity)
    end

    render json: {
      job_id: song_download.job_id,
      status: song_download.status,
      total_tracks: song_download.total_tracks
    }, status: :accepted
  rescue TrafiClient::Error => e
    render_error(e.message, status: :bad_gateway)
  end
end
