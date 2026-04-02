class MusicBrainzMatcherService
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
    results = search_results
    return nil if results.empty?

    best_match = results.map { |r| [r, score(r)] }.max_by(&:last)
    return nil if best_match.last < CONFIDENCE_THRESHOLD

    best_match.first
  end

  private

  def search_results
    service = MusicBrainzService.new

    if @track.isrc.present?
      results = service.search_recording_by_isrc(isrc: @track.isrc)
      return results if results.any?
    end

    artist_name = YoutubeMetadataEnricher.clean_for_search(@track.artist.name)
    title = YoutubeMetadataEnricher.clean_for_search(@track.title)

    service.search_recording(artist: artist_name, title: title)
  end

  def score(result)
    title_score(result) * TITLE_WEIGHT +
      artist_score(result) * ARTIST_WEIGHT +
      duration_score(result) * DURATION_WEIGHT +
      track_number_score(result) * TRACK_NUMBER_WEIGHT
  end

  def title_score(result)
    track_title = normalize(@track.title)
    mb_title = normalize(result[:title])

    return 1.0 if track_title == mb_title
    return 0.8 if mb_title.include?(track_title) || track_title.include?(mb_title)
    0.0
  end

  def artist_score(result)
    track_artist = normalize(@track.artist.name)
    mb_artist = normalize(result[:artist_name])

    return 1.0 if track_artist == mb_artist
    return 0.8 if mb_artist.include?(track_artist) || track_artist.include?(mb_artist)
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
    return 0.5 if @track.track_number.nil?

    release = best_release(result)
    return 0.5 if release.nil?

    0.5
  end

  def best_release(result)
    releases = result[:releases] || []
    return nil if releases.empty?

    album_title = normalize(@track.album.title)

    title_match = releases.find { |r| normalize(r[:title]) == album_title }
    return title_match if title_match

    dated = releases.select { |r| r[:date].present? }
    return dated.min_by { |r| r[:date] } if dated.any?

    releases.first
  end

  def normalize(text)
    text.to_s
      .downcase
      .gsub(/[^\p{L}\p{N}\s]/, "")
      .gsub(/\s+/, " ")
      .strip
  end
end
