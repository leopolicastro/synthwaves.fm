class AppleMusicMatcherService
  CONFIDENCE_THRESHOLD = 0.6

  TITLE_WEIGHT = 0.4
  ARTIST_WEIGHT = 0.3
  DURATION_WEIGHT = 0.2
  TRACK_NUMBER_WEIGHT = 0.1

  def self.call(track)
    new(track).call
  end

  def initialize(track)
    @track = track
  end

  def call
    artist_name = YoutubeMetadataEnricher.clean_for_search(@track.artist.name)
    title = YoutubeMetadataEnricher.clean_for_search(@track.title)

    service = AppleMusicService.new
    results = service.search_song(artist: artist_name, title: title)
    return nil if results.empty?

    best_match = results.map { |r| [r, score(r)] }.max_by(&:last)
    return nil if best_match.last < CONFIDENCE_THRESHOLD

    best_match.first
  end

  private

  def score(result)
    title_score(result) * TITLE_WEIGHT +
      artist_score(result) * ARTIST_WEIGHT +
      duration_score(result) * DURATION_WEIGHT +
      track_number_score(result) * TRACK_NUMBER_WEIGHT
  end

  def title_score(result)
    track_title = normalize(@track.title)
    apple_title = normalize(result[:name])

    return 1.0 if track_title == apple_title
    return 0.8 if apple_title.include?(track_title) || track_title.include?(apple_title)
    0.0
  end

  def artist_score(result)
    track_artist = normalize(@track.artist.name)
    apple_artist = normalize(result[:artist_name])

    return 1.0 if track_artist == apple_artist
    return 0.8 if apple_artist.include?(track_artist) || track_artist.include?(apple_artist)
    0.0
  end

  def duration_score(result)
    return 0.5 if @track.duration.nil? || result[:duration_ms].nil?

    diff = (@track.duration * 1000 - result[:duration_ms]).abs
    if diff < 3000 then 1.0
    elsif diff < 10_000 then 0.5
    else 0.0
    end
  end

  def track_number_score(result)
    return 0.5 if @track.track_number.nil? || result[:track_number].nil?
    (@track.track_number == result[:track_number]) ? 1.0 : 0.0
  end

  def normalize(text)
    text.to_s
      .downcase
      .gsub(/[^\p{L}\p{N}\s]/, "")
      .gsub(/\s+/, " ")
      .strip
  end
end
