class Folder < ApplicationRecord
  belongs_to :user
  has_many :videos, dependent: :nullify
  has_one_attached :cover_image
  has_many :favorites, as: :favorable, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :user_id}

  scope :search, ->(q) { q.present? ? where("name LIKE ?", "%#{q}%") : all }
end
