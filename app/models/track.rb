class Track < ApplicationRecord
  belongs_to :album
  belongs_to :artist
  has_one_attached :audio_file
  has_many :playlist_tracks, dependent: :destroy
  has_many :playlists, through: :playlist_tracks
  has_many :play_histories, dependent: :destroy
  has_many :favorites, as: :favorable, dependent: :destroy

  validates :title, presence: true

  scope :music, -> { joins(:artist).merge(Artist.music) }
  scope :podcast, -> { joins(:artist).merge(Artist.podcast) }
  scope :streamable, -> { where(youtube_video_id: nil) }

  ALBUM_SORT_OPTIONS = {
    "disc_number" => "Track Number",
    "created_at" => "Date Added",
    "title" => "Title",
    "duration" => "Duration"
  }.freeze

  def youtube?
    youtube_video_id.present?
  end

  scope :search, ->(query) {
    if query.present?
      joins(:artist, :album)
        .where("tracks.title LIKE :q OR artists.name LIKE :q OR albums.title LIKE :q", q: "%#{query}%")
    end
  }

  after_create_commit :convert_audio_if_needed

  private

  def convert_audio_if_needed
    return unless audio_file.attached?
    return unless AudioConversionJob::CONVERTIBLE_FORMATS.include?(file_format)

    AudioConversionJob.perform_later(id)
  end
end
