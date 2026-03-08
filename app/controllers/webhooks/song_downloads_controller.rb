class Webhooks::SongDownloadsController < ActionController::API
  before_action :find_song_download

  def create
    if params[:file].present?
      handle_success
    else
      handle_failure
    end

    head :ok
  end

  private

  def find_song_download
    @song_download = SongDownload.find_by(webhook_token: params[:token])
    head :not_found unless @song_download
  end

  def handle_success
    metadata = if params[:metadata].is_a?(String)
      JSON.parse(params[:metadata])
    else
      params[:metadata]&.to_unsafe_h || {}
    end

    @song_download.process_track(
      file: params[:file],
      thumbnail: params[:thumbnail],
      metadata: metadata
    )
  end

  def handle_failure
    body = JSON.parse(request.body.read) rescue {}
    @song_download.mark_track_failed(
      track_number: body["track_number"],
      error: body["error"] || "Unknown error"
    )
  end
end
