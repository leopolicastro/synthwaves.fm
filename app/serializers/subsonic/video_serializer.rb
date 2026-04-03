module Subsonic
  class VideoSerializer
    def self.to_entry(video)
      {
        id: video.id.to_s,
        title: video.title,
        description: video.description,
        duration: video.duration&.to_i,
        width: video.width,
        height: video.height,
        size: video.file_size,
        contentType: "video/mp4",
        fileFormat: video.file_format,
        folderId: video.folder_id&.to_s,
        folderName: video.folder&.name,
        episodeNumber: video.episode_number,
        seasonNumber: video.season_number,
        created: video.created_at.iso8601
      }.compact
    end
  end
end
