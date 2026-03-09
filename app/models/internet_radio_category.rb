class InternetRadioCategory < ApplicationRecord
  has_many :internet_radio_stations, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :with_stations, -> { where("stations_count > 0") }

  private

  def generate_slug
    self.slug = name.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").parameterize
  end
end
