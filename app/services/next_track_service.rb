class NextTrackService
  Result = Data.define(:track, :url)

  def self.call(station)
    new(station).call
  end

  def initialize(station)
    @station = station
  end

  def call
    entry = RadioQueueService.new(@station).advance!
    return nil unless entry

    track = entry.track
    return nil unless track&.audio_file&.attached?

    ensure_url_options!
    url = track.audio_file.url(expires_in: 1.hour)

    Result.new(track: track, url: url)
  end

  private

  def ensure_url_options!
    return if ActiveStorage::Current.url_options.present?

    ActiveStorage::Current.url_options = {
      host: ENV.fetch("APP_HOST", "localhost"),
      protocol: ENV.fetch("APP_PROTOCOL", "http")
    }
  end
end
