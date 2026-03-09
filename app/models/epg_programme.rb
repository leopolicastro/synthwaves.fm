class EPGProgramme < ApplicationRecord
  validates :channel_id, presence: true
  validates :title, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true

  scope :for_channel, ->(tvg_id) { where(channel_id: tvg_id) }
  scope :current, -> { where("starts_at <= ? AND ends_at > ?", Time.current, Time.current) }
  scope :upcoming, -> { where("starts_at > ?", Time.current).order(:starts_at) }
  scope :expired, -> { where("ends_at <= ?", Time.current) }
  scope :in_window, ->(start_time, end_time) { where("starts_at < ? AND ends_at > ?", end_time, start_time) }

  def self.now_playing(tvg_id)
    for_channel(tvg_id).current.first
  end

  def self.up_next(tvg_id, limit: 3)
    for_channel(tvg_id).upcoming.limit(limit)
  end

  def live?
    starts_at <= Time.current && ends_at > Time.current
  end

  def progress_percentage
    return 0 unless live?

    elapsed = Time.current - starts_at
    total = ends_at - starts_at
    return 0 if total <= 0

    ((elapsed / total) * 100).clamp(0, 100).round
  end

  def remaining_minutes
    return 0 unless live?

    ((ends_at - Time.current) / 60.0).ceil
  end
end
