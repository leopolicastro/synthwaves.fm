class RadioStation < ApplicationRecord
  STATUSES = %w[stopped starting active idle error].freeze
  PLAYBACK_MODES = %w[shuffle sequential].freeze
  BITRATES = [128, 192, 256, 320].freeze

  belongs_to :playlist
  belongs_to :user
  belongs_to :current_track, class_name: "Track", optional: true
  belongs_to :queued_track, class_name: "Track", optional: true

  has_many :radio_queue_tracks, dependent: :delete_all
  has_one_attached :image

  validates :status, inclusion: {in: STATUSES}
  validates :playback_mode, inclusion: {in: PLAYBACK_MODES}
  validates :bitrate, inclusion: {in: BITRATES}
  validates :crossfade_duration, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 10}
  validates :favorites_weight, numericality: {greater_than_or_equal_to: 1.0, less_than_or_equal_to: 5.0}
  validates :mount_point, presence: true, uniqueness: true, format: {with: /\A\/[a-z0-9-]+\.mp3\z/}
  validates :playlist_id, uniqueness: true

  before_validation :generate_mount_point, on: :create

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def display_image
    if current_track&.album&.cover_image&.attached?
      current_track.album.cover_image
    elsif image.attached?
      image
    end
  end

  def slug
    mount_point.delete_prefix("/").delete_suffix(".mp3")
  end

  def self.find_by_slug!(slug)
    find_by!(mount_point: "/#{slug}.mp3")
  end

  def listen_url
    host = ENV.fetch("ICECAST_HOST", "localhost")
    protocol = ENV.fetch("ICECAST_PROTOCOL", "http")
    port = ENV.fetch("ICECAST_PORT", "8000")
    if port == "443" || port == "80"
      "#{protocol}://#{host}#{mount_point}"
    else
      "#{protocol}://#{host}:#{port}#{mount_point}"
    end
  end

  def broadcast_status
    RadioStationBroadcaster.status(self)
  end

  def broadcast_now_playing
    RadioStationBroadcaster.now_playing(self)
  end

  def broadcast_queue
    RadioStationBroadcaster.queue(self)
  end

  def upcoming_tracks(limit = 3)
    radio_queue_tracks.upcoming.limit(limit).includes(track: [:artist, {album: {cover_image_attachment: :blob}}])
  end

  def recently_played_tracks(limit = 10)
    radio_queue_tracks.played.offset(2).limit(limit).includes(track: [:artist, {album: {cover_image_attachment: :blob}}])
  end

  private

  def generate_mount_point
    return if mount_point.present?
    slug = playlist&.name&.parameterize.presence || SecureRandom.hex(4)
    self.mount_point = "/#{slug}.mp3"
  end
end
