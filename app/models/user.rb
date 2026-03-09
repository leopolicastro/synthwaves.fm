class User < ApplicationRecord
  include Themeable

  has_many :api_keys, class_name: "APIKey", dependent: :destroy

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :play_histories, dependent: :destroy
  has_many :radio_stations, dependent: :destroy
  has_many :downloads, dependent: :destroy
  has_many :videos, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :user_recordings, dependent: :destroy
  has_many :recordings, through: :user_recordings

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    format: {with: URI::MailTo::EMAIL_REGEXP}
end
