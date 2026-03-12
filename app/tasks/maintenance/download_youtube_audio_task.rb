module Maintenance
  class DownloadYoutubeAudioTask < MaintenanceTasks::Task
    def collection
      Track.where.not(youtube_video_id: [nil, ""])
           .left_joins(:audio_file_attachment)
           .where(active_storage_attachments: { id: nil })
    end

    def count
      collection.count
    end

    def process(track)
      url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
      MediaDownloadJob.perform_later(track.id, url, user_id: User.find_by(admin: true)&.id)
    end
  end
end
