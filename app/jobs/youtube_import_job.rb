class YoutubeImportJob < ApplicationJob
  queue_as :default

  def perform(url, category: "music", download: false, user_id: nil)
    user = User.find(user_id)
    album = YoutubePlaylistImportService.call(url, category: category, api_key: user.youtube_api_key, user: user)

    if download && album && user_id
      album.tracks.where.not(youtube_video_id: [nil, ""]).find_each do |track|
        next if track.audio_file.attached?

        video_url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
        MediaDownloadJob.perform_later(track.id, video_url, user_id: user_id)
      end
    end
  end
end
