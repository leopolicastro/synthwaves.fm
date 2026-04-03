class FolderVideoUploadService
  def self.call(user:, folder_name:, signed_blob_ids:, filenames:, season_number: nil)
    new(user: user, folder_name: folder_name, signed_blob_ids: signed_blob_ids,
      filenames: filenames, season_number: season_number).call
  end

  def initialize(user:, folder_name:, signed_blob_ids:, filenames:, season_number: nil)
    @user = user
    @folder_name = folder_name
    @signed_blob_ids = signed_blob_ids
    @filenames = filenames
    @season_number = season_number
  end

  def call
    ActiveRecord::Base.transaction do
      folder = @user.folders.find_or_create_by!(name: @folder_name)

      @signed_blob_ids.each_with_index do |signed_id, index|
        filename = @filenames[index] || "video_#{index + 1}.mp4"
        parsed = FilenameEpisodeParser.parse(filename, default_season: @season_number)
        file_format = filename[/\.\w+$/]&.delete(".")

        blob = ActiveStorage::Blob.find_signed!(signed_id)

        video = folder.videos.new(
          user: @user,
          title: parsed.title.presence || filename.sub(/\.\w+$/, ""),
          season_number: parsed.season_number || @season_number,
          episode_number: parsed.episode_number || (index + 1),
          file_format: file_format,
          file_size: blob.byte_size,
          status: "processing"
        )
        video.file.attach(blob)
        video.save!
      end

      folder
    end
  end
end
