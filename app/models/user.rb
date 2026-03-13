class User < ApplicationRecord
  include Themeable

  has_many :api_keys, class_name: "APIKey", dependent: :destroy

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :artists, dependent: :destroy
  has_many :albums, dependent: :destroy
  has_many :tracks, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :play_histories, dependent: :destroy
  has_many :radio_stations, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :downloads, dependent: :destroy
  has_many :videos, dependent: :destroy
  has_many :video_playback_positions, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :user_recordings, dependent: :destroy
  has_many :recordings, through: :user_recordings

  encrypts :youtube_api_key

  def favorited_ids_for(type)
    favorites.where(favorable_type: type).pluck(:favorable_id).to_set
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    format: {with: URI::MailTo::EMAIL_REGEXP}

  before_create :generate_subsonic_password, unless: :subsonic_password?

  private

  def generate_subsonic_password
    self.subsonic_password = SecureRandom.hex(16)
  end
end
