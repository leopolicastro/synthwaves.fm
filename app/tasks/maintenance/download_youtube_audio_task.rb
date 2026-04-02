module Maintenance
  class DownloadYoutubeAudioTask < MaintenanceTasks::Task
    def collection
      Track.where.not(youtube_video_id: [nil, ""])
        .left_joins(:audio_file_attachment)
        .where(active_storage_attachments: {id: nil})
        .where("download_status IS NULL OR download_status != ?", "failed")
    end

    def count
      collection.count
    end

    def process(track)
      @index ||= 0
      url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
      MediaDownloadJob.set(wait: @index * 15.seconds).perform_later(track.id, url, user_id: User.find_by(admin: true)&.id)
      @index += 1
    end
  end
end
