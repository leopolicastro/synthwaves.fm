class Artist < ApplicationRecord
  has_many :albums, dependent: :destroy
  has_many :tracks, dependent: :destroy
  has_many :favorites, as: :favorable, dependent: :destroy

  enum :category, { music: "music", podcast: "podcast" }, default: "music"

  CATEGORIES = categories.keys

  SORT_OPTIONS = {
    "name" => "Name",
    "created_at" => "Recently Added"
  }.freeze

  validates :name, presence: true, uniqueness: true

  scope :search, ->(query) {
    where("artists.name LIKE :q", q: "%#{query}%") if query.present?
  }
end
