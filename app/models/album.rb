class Album < ApplicationRecord
  belongs_to :artist
  has_many :tracks, dependent: :destroy
  has_one_attached :cover_image
  has_many :favorites, as: :favorable, dependent: :destroy

  SORT_OPTIONS = {
    "title" => "Title",
    "year" => "Year",
    "created_at" => "Recently Added"
  }.freeze

  validates :title, presence: true, uniqueness: {scope: :artist_id}

  scope :music, -> { joins(:artist).merge(Artist.music) }
  scope :podcast, -> { joins(:artist).merge(Artist.podcast) }
  scope :with_streamable_tracks, -> { joins(:tracks).merge(Track.streamable).distinct }
  scope :search, ->(query) {
    where("albums.title LIKE :q", q: "%#{query}%") if query.present?
  }
end
