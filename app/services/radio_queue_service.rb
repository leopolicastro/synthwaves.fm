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
    return [] if pool.count == 0

    upcoming_ids = @station.radio_queue_tracks.upcoming.pluck(:track_id)
    exclude_ids = build_shuffle_exclusions(pool.count, count, upcoming_ids)
    candidates = pool.where.not(id: exclude_ids)

    pick_random_with_fallback(candidates, pool, upcoming_ids, count)
  end

  def build_shuffle_exclusions(total, count, upcoming_ids)
    exclude_ids = upcoming_ids.dup
    recently_played_limit = [total - count, 0].max
    if recently_played_limit > 0
      exclude_ids += @station.radio_queue_tracks.played.limit(recently_played_limit).pluck(:track_id)
    end
    exclude_ids.uniq
  end

  def pick_random_with_fallback(candidates, pool, upcoming_ids, count)
    favorited_ids = @station.user.favorited_ids_for("Track")
    weight = @station.favorites_weight

    if candidates.count >= count
      selected_ids = weighted_sample(candidates.pluck(:id), count, favorited_ids, weight)
      load_tracks_in_order(selected_ids)
    else
      # Not enough fresh candidates -- relax recently-played constraint but still avoid upcoming duplicates
      first_ids = weighted_sample(candidates.pluck(:id), candidates.count, favorited_ids, weight)
      remaining = count - first_ids.size
      if remaining > 0
        used_ids = (upcoming_ids + first_ids).uniq
        second_ids = weighted_sample(pool.where.not(id: used_ids).pluck(:id), remaining, favorited_ids, weight)
        load_tracks_in_order(first_ids + second_ids)
      else
        load_tracks_in_order(first_ids)
      end
    end
  end

  # Weighted random sampling without replacement (Efraimidis-Spirakis algorithm).
  # Each item gets a key: rand^(1/weight). Higher weights push keys closer to 1.0,
  # making those items more likely to land at the top when sorted descending.
  # Lighter items can still win with a lucky roll -- no one is starved.
  def weighted_sample(candidate_ids, count, favorited_ids, weight)
    return [] if candidate_ids.empty?
    count = [count, candidate_ids.size].min

    candidate_ids
      .sort_by { |id| -(rand**(1.0 / (favorited_ids.include?(id) ? weight : 1.0))) }
      .first(count)
  end

  def load_tracks_in_order(ids)
    return [] if ids.empty?
    Track.where(id: ids).index_by(&:id).values_at(*ids)
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
