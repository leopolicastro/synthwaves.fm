class Download < ApplicationRecord
  STATUSES = %w[pending processing ready failed cancelled].freeze
  DOWNLOADABLE_TYPES = %w[Track Album Playlist Library].freeze

  belongs_to :user
  belongs_to :downloadable, polymorphic: true, optional: true
  has_one_attached :file

  validates :downloadable_type, inclusion: {in: DOWNLOADABLE_TYPES}
  validates :status, inclusion: {in: STATUSES}

  scope :expired, -> { where(status: "ready").where("updated_at < ?", 1.hour.ago) }
  scope :stale, -> { where(status: %w[pending processing]).where("created_at < ?", 6.hours.ago) }

  def pending?
    status == "pending"
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

  def progress_percentage
    return 0 if total_tracks.zero?
    (processed_tracks.to_f / total_tracks * 100).round
  end

  def filename
    base = case downloadable_type
    when "Track"
      "#{downloadable.artist.name} - #{downloadable.title}"
    when "Album"
      "#{downloadable.artist.name} - #{downloadable.title}"
    when "Playlist"
      downloadable.name
    when "Library"
      "SynthWaves Library Export"
    end

    FilenameUtils.sanitize(base) + ".zip"
  end

  def broadcast_status
    Turbo::StreamsChannel.broadcast_replace_to(
      "downloads_#{user_id}",
      target: "download_#{id}",
      partial: "downloads/status",
      locals: {download: self}
    )
  end

  def broadcast_append
    Turbo::StreamsChannel.broadcast_append_to(
      "downloads_#{user_id}",
      target: "download-notifications",
      partial: "downloads/status",
      locals: {download: self}
    )
    Turbo::StreamsChannel.broadcast_append_to(
      "downloads_#{user_id}",
      target: "downloads-list",
      partial: "downloads/status",
      locals: {download: self}
    )
  end

  private
end
