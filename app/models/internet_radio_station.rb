class InternetRadioStation < ApplicationRecord
  belongs_to :internet_radio_category, optional: true, counter_cache: :stations_count

  has_many :favorites, as: :favorable, dependent: :destroy

  validates :name, presence: true
  validates :stream_url, presence: true
  validates :uuid, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :by_country, ->(code) { where(country_code: code) if code.present? }
  scope :by_tag, ->(tag) { where("tags LIKE ?", "%#{tag}%") if tag.present? }
  scope :search, ->(query) { where("name LIKE ?", "%#{query}%") if query.present? }
  scope :popular, -> { order(votes: :desc) }

  def needs_proxy?
    stream_url.present? && !stream_url.start_with?("https://")
  end

  def display_favicon_url
    return favicon_url if favicon_url.present?
    return unless homepage_url.present?

    domain = URI.parse(homepage_url).host
    "https://www.google.com/s2/favicons?domain=#{domain}&sz=128" if domain.present?
  rescue URI::InvalidURIError
    nil
  end
end
