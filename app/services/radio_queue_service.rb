class RadioQueueService
  WINDOW_SIZE = 20

  def initialize(station)
    @station = station
  end

  def populate!
    @station.radio_queue_tracks.delete_all

    tracks = select_batch(WINDOW_SIZE)
    tracks.each_with_index do |track, idx|
      @station.radio_queue_tracks.create!(track: track, position: idx + 1)
    end

    @station.broadcast_queue
  end

  def advance!
    next_entry = @station.radio_queue_tracks.upcoming.first
    return nil unless next_entry

    next_entry.update!(played_at: Time.current)
    backfill(1)
    @station.broadcast_queue
    next_entry
  end

  def sync_with_playlist!
    playlist_track_ids = streamable_tracks.pluck(:id)
    removed = @station.radio_queue_tracks.upcoming
      .where.not(track_id: playlist_track_ids)
      .delete_all

    if removed > 0
      reindex_positions!
      backfill(removed)
      @station.broadcast_queue
    end
  end

  def clear!
    @station.radio_queue_tracks.delete_all
  end

  private

  def select_batch(count)
    case @station.playback_mode
    when "shuffle" then pick_shuffle_batch(count)
    when "sequential" then pick_sequential_batch(count)
    else []
    end
  end

  def backfill(count)
    return if count <= 0

    max_position = @station.radio_queue_tracks.maximum(:position) || 0
    new_tracks = select_batch(count)

    new_tracks.each_with_index do |track, idx|
      @station.radio_queue_tracks.create!(
        track: track,
        position: max_position + idx + 1
      )
    end
  end

  def pick_shuffle_batch(count)
    pool = streamable_tracks
    total = pool.count
    return [] if total == 0

    upcoming_ids = @station.radio_queue_tracks.upcoming.pluck(:track_id)
    exclude_ids = upcoming_ids.dup

    recently_played_limit = [total - count, 0].max
    if recently_played_limit > 0
      exclude_ids += @station.radio_queue_tracks.played.limit(recently_played_limit).pluck(:track_id)
    end
    exclude_ids.uniq!

    candidates = pool.where.not(id: exclude_ids)

    if candidates.count >= count
      candidates.order("RANDOM()").limit(count).to_a
    else
      # Not enough fresh candidates — relax recently-played constraint but still avoid upcoming duplicates
      first_batch = candidates.order("RANDOM()").to_a
      remaining = count - first_batch.size
      if remaining > 0
        used_ids = (upcoming_ids + first_batch.map(&:id)).uniq
        second_batch = pool.where.not(id: used_ids).order("RANDOM()").limit(remaining).to_a
        first_batch + second_batch
      else
        first_batch
      end
    end
  end

  def pick_sequential_batch(count)
    ordered = @station.playlist.playlist_tracks
      .joins(:track)
      .merge(Track.streamable)
      .order(:position)

    total = ordered.count
    return [] if total == 0

    last_entry = @station.radio_queue_tracks.order(position: :desc).first
    if last_entry
      last_playlist_position = @station.playlist.playlist_tracks
        .find_by(track_id: last_entry.track_id)&.position
    end

    if last_playlist_position
      after = ordered.where("playlist_tracks.position > ?", last_playlist_position).limit(count)
      tracks = after.map(&:track)

      if tracks.size < count
        remaining = count - tracks.size
        tracks += ordered.limit(remaining).map(&:track)
      end

      tracks
    else
      ordered.limit(count).map(&:track)
    end
  end

  def reindex_positions!
    @station.radio_queue_tracks.upcoming.order(:position).each_with_index do |entry, idx|
      entry.update_column(:position, idx + 1) if entry.position != idx + 1
    end
  end

  def streamable_tracks
    @station.playlist.tracks.streamable
  end
end
