class Artist < ApplicationRecord
  include SearchIndexable

  belongs_to :user
  has_many :albums, dependent: :destroy
  has_many :tracks, dependent: :destroy
  has_many :favorites, as: :favorable, dependent: :destroy

  enum :category, {music: "music", podcast: "podcast"}, default: "music"

  CATEGORIES = categories.keys

  SORT_OPTIONS = {
    "name" => "Name",
    "created_at" => "Recently Added"
  }.freeze

  validates :name, presence: true, uniqueness: {scope: :user_id}

  after_update_commit :reindex_tracks_search, if: :saved_change_to_name?

  scope :search, ->(query) {
    where("artists.name LIKE :q", q: "%#{query}%") if query.present?
  }

  private
end
