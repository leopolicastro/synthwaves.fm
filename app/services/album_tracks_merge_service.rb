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
    matched_titles = Set.new

    @owned_tracks.each do |track|
      match = find_match(track)
      if match
        matched_positions << match[:position]
        matched_titles << normalize(match[:title])
      end
    end

    @mb_tracks.select do |mb_track|
      !matched_positions.include?(mb_track[:position]) &&
        !matched_titles.include?(normalize(mb_track[:title]))
    end.map do |mb_track|
      {
        type: :missing,
        position: mb_track[:position],
        title: mb_track[:title],
        duration_ms: mb_track[:duration_ms]
      }
    end.sort_by { |e| e[:position] || 0 }
  end

  private

  def find_match(track)
    by_position = @mb_tracks.find { |mb| match_by_position?(track, mb) }
    return by_position if by_position

    @mb_tracks.find { |mb| match_by_title?(track, mb) }
  end

  def match_by_position?(track, mb)
    track.track_number.present? &&
      mb[:position].present? &&
      track.track_number == mb[:position]
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

  def normalize(text)
    text.to_s.downcase.gsub(/[^\p{L}\p{N}\s]/, "").gsub(/\s+/, " ").strip
  end
end
