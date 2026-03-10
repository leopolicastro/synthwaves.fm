class Video < ApplicationRecord
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

  def downloading?
    download_status == "downloading"
  end

  def download_failed?
    download_status == "failed"
  end

  def download_completed?
    download_status == "completed"
  end

  private

  def convert_video
    return unless file.attached?

    VideoConversionJob.perform_later(id)
  end
end
