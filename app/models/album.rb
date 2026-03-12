class Album < ApplicationRecord
  include SearchIndexable

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

  after_update_commit :reassign_tracks_to_artist, if: :saved_change_to_artist_id?
  after_update_commit :reindex_tracks_search, if: -> {
    saved_change_to_title? || saved_change_to_artist_id?
  }

  scope :music, -> { joins(:artist).merge(Artist.music) }
  scope :podcast, -> { joins(:artist).merge(Artist.podcast) }
  scope :with_streamable_tracks, -> { joins(:tracks).merge(Track.streamable).distinct }
  scope :search, ->(query) {
    where("albums.title LIKE :q", q: "%#{query}%") if query.present?
  }

  private

  def reassign_tracks_to_artist
    tracks.update_all(artist_id: artist_id)
  end

end
