class AlbumTracksMergeService
  def self.call(owned_tracks, mb_tracks)
    new(owned_tracks, mb_tracks).call
  end

  def initialize(owned_tracks, mb_tracks)
    @owned_tracks = owned_tracks
    @mb_tracks = mb_tracks
  end

  def call
    matched_positions = Set.new
    entries = []

    @owned_tracks.each do |track|
      match = find_match(track)
      matched_positions << match[:position] if match
      entries << {type: :owned, track: track, position: track.track_number || 0}
    end

    @mb_tracks.each do |mb_track|
      next if matched_positions.include?(mb_track[:position])

      entries << {
        type: :missing,
        position: mb_track[:position],
        title: mb_track[:title],
        duration_ms: mb_track[:duration_ms]
      }
    end

    entries.sort_by { |e| e[:position] || 0 }
  end

  private

  def find_match(track)
    @mb_tracks.find do |mb|
      match_by_title?(track, mb) || match_by_position?(track, mb)
    end
  end

  def match_by_title?(track, mb)
    owned = normalize(track.title)
    mb_title = normalize(mb[:title])

    return true if owned == mb_title
    return true if owned.include?(mb_title) || mb_title.include?(owned)

    owned_words = owned.split.to_set
    mb_words = mb_title.split.to_set
    overlap = (owned_words & mb_words).size
    smaller = [owned_words.size, mb_words.size].min
    smaller > 0 && overlap.to_f / smaller >= 0.7
  end

  def match_by_position?(track, mb)
    track.track_number.present? &&
      mb[:position].present? &&
      track.track_number == mb[:position]
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^\p{L}\p{N}\s]/, "").gsub(/\s+/, " ").strip
  end
end
