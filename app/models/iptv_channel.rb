class IPTVChannel < ApplicationRecord
  belongs_to :iptv_category, optional: true, counter_cache: :channels_count

  validates :name, presence: true
  validates :stream_url, presence: true
  validates :tvg_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :by_country, ->(country) { where(country: country) if country.present? }
  scope :by_language, ->(language) { where(language: language) if language.present? }
  scope :search, ->(query) { where("name LIKE ?", "%#{query}%") if query.present? }
end
