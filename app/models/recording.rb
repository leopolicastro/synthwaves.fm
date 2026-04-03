class Recording < ApplicationRecord
  STATUSES = %w[scheduled recording processing ready failed cancelled].freeze

  belongs_to :iptv_channel
  belongs_to :epg_programme, optional: true
  has_many :user_recordings, dependent: :destroy
  has_many :users, through: :user_recordings
  has_one_attached :file

  validates :title, presence: true
  validates :status, inclusion: {in: STATUSES}
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at
  validate :max_duration

  SORT_OPTIONS = {
    "created_at" => "Date Added",
    "title" => "Title",
    "starts_at" => "Scheduled Time",
    "status" => "Status"
  }.freeze

  scope :upcoming, -> { where(status: "scheduled").where("starts_at > ?", Time.current).order(:starts_at) }
  scope :active, -> { where(status: %w[scheduled recording processing]) }
  scope :completed, -> { where(status: "ready").order(created_at: :desc) }

  scope :search, ->(query) {
    if query.present?
      joins(:iptv_channel)
        .where("recordings.title LIKE :q OR iptv_channels.name LIKE :q", q: "%#{query}%")
    end
  }

  scope :by_status, ->(status) {
    where(status: status) if status.present? && status.in?(STATUSES)
  }

  def scheduled?
    status == "scheduled"
  end

  def recording?
    status == "recording"
  end

  def processing?
    status == "processing"
  end

  def ready?
    status == "ready"
  end

  def failed?
    status == "failed"
  end

  def cancelled?
    status == "cancelled"
  end

  def cancellable?
    scheduled? || recording?
  end

  def filename
    FilenameUtils.sanitize(title) + ".mp4"
  end

  def broadcast_status
    user_recordings.includes(:user).find_each do |ur|
      Turbo::StreamsChannel.broadcast_replace_to(
        "recordings_#{ur.user_id}",
        target: "recording_#{id}",
        partial: "recordings/recording",
        locals: {recording: self}
      )
    end
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    errors.add(:ends_at, "must be after starts_at") unless ends_at > starts_at
  end

  def max_duration
    return if starts_at.blank? || ends_at.blank?
    errors.add(:base, "Recording cannot exceed 4 hours") if (ends_at - starts_at) > 4.hours.to_i
  end
end
