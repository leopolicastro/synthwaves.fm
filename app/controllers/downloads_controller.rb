class DownloadsController < ApplicationController
  def index
    @downloads = Current.user.downloads.order(created_at: :desc)
  end

  def create
    downloadable_type = params[:downloadable_type]
    downloadable_id = params[:downloadable_id]

    unless Download::DOWNLOADABLE_TYPES.include?(downloadable_type)
      redirect_back fallback_location: library_path, alert: "Invalid download type."
      return
    end

    downloadable = resolve_downloadable(downloadable_type, downloadable_id)
    if downloadable_type != "Library" && downloadable.nil?
      redirect_back fallback_location: library_path, alert: "Could not find the requested item."
      return
    end

    existing = find_existing_download(downloadable_type, downloadable_id)
    if existing
      redirect_to download_path(existing), notice: "A download is already being prepared."
      return
    end

    attrs = {downloadable_type: downloadable_type, status: "pending"}
    attrs[:downloadable] = downloadable if downloadable
    download = Current.user.downloads.create!(attrs)

    DownloadZipJob.perform_later(download.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("download-notifications",
          partial: "downloads/status",
          locals: {download: download})
      end
      format.html { redirect_to download_path(download), notice: "Download is being prepared." }
    end
  end

  def show
    @download = Current.user.downloads.find(params[:id])
  end

  def destroy
    download = Current.user.downloads.find(params[:id])

    unless download.pending? || download.processing?
      redirect_to downloads_path, alert: "Only pending or in-progress downloads can be cancelled."
      return
    end

    download.update!(status: "cancelled")
    download.file.purge if download.file.attached?
    download.broadcast_status

    redirect_to downloads_path, notice: "Download cancelled."
  end

  def file
    download = Current.user.downloads.find(params[:id])

    unless download.ready? && download.file.attached?
      redirect_to download_path(download), alert: "Download is not ready yet."
      return
    end

    redirect_to rails_blob_path(download.file, disposition: "attachment", filename: download.filename), allow_other_host: true
  end

  private

  def resolve_downloadable(type, id)
    case type
    when "Track"
      Track.find_by(id: id)
    when "Album"
      Album.find_by(id: id)
    when "Playlist"
      Current.user.playlists.find_by(id: id)
    when "Library"
      nil
    end
  end

  def find_existing_download(type, id)
    scope = Current.user.downloads.where(downloadable_type: type, status: %w[pending processing ready])
    if id.present?
      scope.find_by(downloadable_id: id)
    else
      scope.find_by(downloadable_id: nil)
    end
  end
end
