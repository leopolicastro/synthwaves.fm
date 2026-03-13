class Track < ApplicationRecord
  include Downloadable

  belongs_to :album
  belongs_to :artist
  belongs_to :user
  has_one_attached :audio_file
  has_many :playlist_tracks, dependent: :destroy
  has_many :playlists, through: :playlist_tracks
  has_many :play_histories, dependent: :destroy
  has_many :favorites, as: :favorable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validates :title, presence: true

  scope :music, -> { joins(:artist).merge(Artist.music) }
  scope :podcast, -> { joins(:artist).merge(Artist.podcast) }
  scope :streamable, -> { joins(:audio_file_attachment) }

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
      sanitized = query.gsub(/["\*\(\)]/, "")
      fts_query = sanitized.split.map { |term| "\"#{term}\"*" }.join(" ")
      where("tracks.id IN (SELECT CAST(track_id AS INTEGER) FROM tracks_search WHERE tracks_search MATCH ?)", fts_query)
    end
  }

  after_create_commit :convert_audio_if_needed
  after_create_commit :add_to_search_index
  after_update_commit :update_search_index, if: -> {
    saved_change_to_title? || saved_change_to_album_id? || saved_change_to_artist_id?
  }
  after_destroy_commit :remove_from_search_index

  private

  def convert_audio_if_needed
    return unless audio_file.attached?
    return unless AudioConversionJob::CONVERTIBLE_FORMATS.include?(file_format)

    AudioConversionJob.perform_later(id)
  end

  def add_to_search_index
    self.class.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "INSERT INTO tracks_search (track_title, artist_name, album_title, track_id) VALUES (?, ?, ?, ?)",
        title, artist.name, album.title, id
      ])
    )
  end

  def update_search_index
    remove_from_search_index
    add_to_search_index
  end

  def remove_from_search_index
    self.class.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "DELETE FROM tracks_search WHERE track_id = ?", id.to_s
      ])
    )
  end
end
