class NextTrackService
  Result = Data.define(:track, :url)

  def self.call(station)
    new(station).call
  end

  def initialize(station)
    @station = station
  end

  def call
    track = select_next_track
    return nil unless track&.audio_file&.attached?

    ensure_url_options!
    url = track.audio_file.url(expires_in: 1.hour)
    @station.update!(current_track: track, last_track_at: Time.current)

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

  def select_next_track
    streamable_tracks = @station.playlist.tracks.streamable
    return nil if streamable_tracks.none?

    case @station.playback_mode
    when "shuffle"
      pick_shuffle(streamable_tracks)
    when "sequential"
      pick_sequential(streamable_tracks)
    end
  end

  def pick_shuffle(tracks)
    total = tracks.count
    return tracks.order("RANDOM()").first if total <= 1

    # Exclude current track, then pick randomly
    candidates = tracks.where.not(id: @station.current_track_id)

    # Pick using random offset for better distribution than ORDER BY RANDOM()
    count = candidates.count
    candidates.offset(rand(count)).first
  end

  def pick_sequential(tracks)
    ordered = @station.playlist.playlist_tracks
      .joins(:track)
      .merge(Track.streamable)
      .order(:position)

    if @station.current_track_id
      current_position = ordered.find_by(track_id: @station.current_track_id)&.position
      if current_position
        next_pt = ordered.where("position > ?", current_position).first
        return next_pt.track if next_pt
      end
    end

    ordered.first&.track
  end
end
