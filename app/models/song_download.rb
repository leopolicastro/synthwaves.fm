class SongDownload < ApplicationRecord
  belongs_to :user

  validates :job_id, presence: true, uniqueness: true
  validates :webhook_token, presence: true, uniqueness: true
  validates :url, presence: true
  validates :source_type, presence: true, inclusion: {in: %w[url search]}
  validates :status, presence: true, inclusion: {in: %w[queued processing completed failed partially_failed]}

  before_validation :generate_webhook_token, on: :create

  def process_track(file:, thumbnail:, metadata:)
    update!(status: "processing") if status == "queued"

    itunes = ItunesSearch.call(
      artist: metadata["artist"],
      title: metadata["title"]
    )

    artist_name = itunes&.dig(:artist) || metadata["artist"] || "Unknown Artist"
    album_title = itunes&.dig(:album) || "Downloads"
    artist = Artist.find_or_create_by!(name: artist_name)
    album = Album.find_or_create_by!(title: album_title, artist: artist) do |a|
      a.year = itunes&.dig(:year)
      a.genre = itunes&.dig(:genre)
    end

    track = Track.create!(
      title: itunes&.dig(:title) || metadata["title"] || "Unknown Title",
      artist: artist,
      album: album,
      track_number: itunes&.dig(:track_number) || metadata["track_number"],
      disc_number: itunes&.dig(:disc_number) || metadata["disc_number"] || 1,
      duration: metadata["duration"],
      file_format: "mp3"
    )

    track.audio_file.attach(
      io: file,
      filename: "#{track.title}.mp3",
      content_type: "audio/mpeg"
    )

    attach_cover_art(album, itunes, thumbnail)

    increment!(:tracks_received)
    update_status!
  end

  def mark_track_failed(track_number:, error:)
    Rails.logger.error("SongDownload #{id} track #{track_number} failed: #{error}")
    increment!(:tracks_failed)
    update_status!
  end

  def finished?
    total_tracks.present? && tracks_received + tracks_failed >= total_tracks
  end

  def update_status!
    return unless finished?

    if tracks_failed == 0
      update!(status: "completed")
    elsif tracks_received == 0
      update!(status: "failed")
    else
      update!(status: "partially_failed")
    end
  end

  private

  def generate_webhook_token
    self.webhook_token ||= SecureRandom.urlsafe_base64(32)
  end

  def attach_cover_art(album, itunes, thumbnail)
    return if album.cover_image.attached?

    artwork_url = itunes&.dig(:artwork_url)
    if artwork_url
      response = HTTP.get(artwork_url)
      if response.status.success?
        album.cover_image.attach(
          io: StringIO.new(response.body.to_s),
          filename: "cover.jpg",
          content_type: response.content_type.mime_type
        )
        return
      end
    end

    return unless thumbnail

    album.cover_image.attach(
      io: thumbnail,
      filename: "cover.jpg",
      content_type: thumbnail.content_type || "image/jpeg"
    )
  end
end
