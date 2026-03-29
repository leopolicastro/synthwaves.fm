class RadioStation < ApplicationRecord
  STATUSES = %w[stopped starting active idle error].freeze
  PLAYBACK_MODES = %w[shuffle sequential].freeze
  BITRATES = [128, 192, 256, 320].freeze

  belongs_to :playlist
  belongs_to :user
  belongs_to :current_track, class_name: "Track", optional: true
  belongs_to :queued_track, class_name: "Track", optional: true

  validates :status, inclusion: {in: STATUSES}
  validates :playback_mode, inclusion: {in: PLAYBACK_MODES}
  validates :bitrate, inclusion: {in: BITRATES}
  validates :crossfade_duration, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 10}
  validates :mount_point, presence: true, uniqueness: true, format: {with: /\A\/[a-z0-9-]+\.mp3\z/}
  validates :playlist_id, uniqueness: true

  before_validation :generate_mount_point, on: :create

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

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
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_stations_#{user_id}",
      target: "radio_station_#{id}",
      partial: "radio_stations/station",
      locals: {station: self}
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_station_public_#{id}",
      target: "public_status_#{id}",
      partial: "radio_stations/status_badge",
      locals: {station: self}
    )
  end

  def broadcast_now_playing
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_stations_#{user_id}",
      target: "now_playing_#{id}",
      partial: "radio_stations/now_playing",
      locals: {station: self}
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "radio_station_public_#{id}",
      target: "now_playing_#{id}",
      partial: "radio_stations/now_playing",
      locals: {station: self}
    )
  end

  private

  def generate_mount_point
    return if mount_point.present?
    slug = playlist&.name&.parameterize.presence || SecureRandom.hex(4)
    self.mount_point = "/#{slug}.mp3"
  end
end
