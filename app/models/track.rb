class Track < ApplicationRecord
  belongs_to :album
  belongs_to :artist
  has_one_attached :audio_file
  has_many :playlist_tracks, dependent: :destroy
  has_many :playlists, through: :playlist_tracks
  has_many :play_histories, dependent: :destroy
  has_many :favorites, as: :favorable, dependent: :destroy

  validates :title, presence: true

  after_create_commit :convert_audio_if_needed

  private

  def convert_audio_if_needed
    return unless audio_file.attached?
    return unless AudioConversionJob::CONVERTIBLE_FORMATS.include?(file_format)

    AudioConversionJob.perform_later(id)
  end
end
