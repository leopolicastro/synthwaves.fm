class Video < ApplicationRecord
  include Downloadable

  FOLDER_SORT_OPTIONS = {
    "episode_number" => "Episode Number",
    "title" => "Title",
    "created_at" => "Date Added"
  }.freeze

  belongs_to :user
  belongs_to :folder, optional: true
  has_one_attached :file
  has_one_attached :thumbnail
  has_many :favorites, as: :favorable, dependent: :destroy

  validates :title, presence: true

  scope :ready, -> { where(status: "ready") }
  scope :search, ->(q) { q.present? ? where("title LIKE ?", "%#{q}%") : all }
  scope :standalone, -> { where(folder_id: nil) }
  scope :in_folder, -> { where.not(folder_id: nil) }
  scope :ordered, -> { order(:season_number, :episode_number) }

  after_create_commit :convert_video

  private

  def convert_video
    return unless file.attached?

    VideoConversionJob.perform_later(id)
  end
end
