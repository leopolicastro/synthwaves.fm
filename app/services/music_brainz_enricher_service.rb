class MusicBrainzEnricherService
  GENERIC_TAGS = %w[music].freeze

  def self.call(track)
    new(track).call
  end

  def initialize(track)
    @track = track
  end

  def call
    return :skipped if recently_enriched?

    match = MusicBrainzMatcherService.call(@track)

    if match
      apply_match(match)
      :matched
    else
      @track.update!(musicbrainz_enrichment_status: "unmatched", musicbrainz_enriched_at: Time.current)
      :unmatched
    end
  rescue => e
    @track.update!(musicbrainz_enrichment_status: "failed")
    Rails.logger.error("MusicBrainzEnricherService failed for track #{@track.id}: #{e.message}")
    :failed
  ensure
    queue_apple_music_enrichment
  end

  private

  def recently_enriched?
    @track.musicbrainz_enrichment_status == "matched" &&
      @track.musicbrainz_enriched_at.present? &&
      @track.musicbrainz_enriched_at > 30.days.ago
  end

  def apply_match(match)
    @track.update!(
      musicbrainz_recording_id: match[:mbid],
      musicbrainz_enrichment_status: "matched",
      musicbrainz_enriched_at: Time.current
    )

    apply_release_year(match)
    assign_genres(match[:tags])
    update_album(match)
    update_artist(match)
  end

  def apply_release_year(match)
    return if @track.release_year.present?

    release = best_release(match)
    return if release.nil? || release[:date].blank?

    year = parse_year(release[:date])
    @track.update!(release_year: year) if year
  end

  def assign_genres(tags)
    return if tags.blank?

    tags.first(10).each do |name|
      normalized = name.strip.downcase
      next if GENERIC_TAGS.include?(normalized)

      tag = Tag.find_or_create_by!(name: normalized, tag_type: "genre")
      Tagging.find_or_create_by!(
        tag: tag,
        taggable: @track,
        user: @track.user
      )
    end
  end

  def update_album(match)
    release = best_release(match)
    return if release.nil?

    @track.album.update!(musicbrainz_release_id: release[:mbid]) if release[:mbid].present?
  end

  def update_artist(match)
    return if match[:artist_mbid].blank?

    @track.artist.update!(musicbrainz_artist_id: match[:artist_mbid])
  end

  def best_release(match)
    releases = match[:releases] || []
    return nil if releases.empty?

    album_title = normalize(@track.album.title)

    title_match = releases.find { |r| normalize(r[:title]) == album_title }
    return title_match if title_match

    dated = releases.select { |r| r[:date].present? }
    return dated.min_by { |r| r[:date] } if dated.any?

    releases.first
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^\p{L}\p{N}\s]/, "").gsub(/\s+/, " ").strip
  end

  def queue_apple_music_enrichment
    return unless Flipper.enabled?(:apple_music_enrichment)

    AppleMusicEnrichmentJob.set(wait: 5.seconds).perform_later(@track.id)
  end

  def parse_year(date_string)
    date_string[0, 4]&.to_i
  rescue
    nil
  end
end
