module DownloadBroadcastable
  extend ActiveSupport::Concern

  private

  def broadcast_download_status(record, user_id, type:)
    return unless record

    Turbo::StreamsChannel.broadcast_replace_to(
      "downloads_#{user_id}",
      target: "media-download-#{type}-#{record.id}",
      partial: "youtube_imports/download_status",
      locals: {record: record, type: type}
    )
  end
end
