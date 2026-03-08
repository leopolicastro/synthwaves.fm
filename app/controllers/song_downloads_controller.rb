class SongDownloadsController < ApplicationController
  def index
    @song_downloads = current_user_downloads.order(created_at: :desc)
  end

  def create
    value = params[:url].to_s.strip
    if value.blank?
      redirect_to song_downloads_path, alert: "Please provide a URL or search query."
      return
    end

    @song_download = if value.match?(%r{\Ahttps?://})
      TrafiClient.download_url(value, user: Current.session.user)
    else
      TrafiClient.download_search(value, user: Current.session.user)
    end

    redirect_to song_downloads_path, notice: "Download started."
  rescue TrafiClient::Error => e
    redirect_to song_downloads_path, alert: "Download failed: #{e.message}"
  end

  private

  def current_user_downloads
    SongDownload.where(user: Current.session.user)
  end
end
