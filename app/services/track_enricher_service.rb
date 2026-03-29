class TrackEnricherService
  def self.call(track)
    new(track).call
  end

  def initialize(track)
    @track = track
  end

  def call
    return :skipped if recently_enriched?

    match = AppleMusicMatcherService.call(@track)

    if match
      apply_match(match)
      :matched
    else
      @track.update!(enrichment_status: "unmatched", enriched_at: Time.current)
      :unmatched
    end
  rescue => e
    @track.update!(enrichment_status: "failed")
    Rails.logger.error("TrackEnricherService failed for track #{@track.id}: #{e.message}")
    :failed
  end

  private

  def recently_enriched?
    @track.enrichment_status == "matched" && @track.enriched_at.present? && @track.enriched_at > 30.days.ago
  end

  def apply_match(match)
    release_year = parse_release_year(match[:release_date])

    @track.update!(
      apple_music_id: match[:apple_music_id],
      isrc: match[:isrc],
      content_rating: match[:content_rating],
      release_year: release_year,
      enrichment_status: "matched",
      enriched_at: Time.current
    )

    assign_genres(match[:genre_names])
    detect_language
    update_artist_storefront
  end

  def assign_genres(genre_names)
    return if genre_names.blank?

    genre_names.each do |name|
      normalized = name.strip.downcase
      next if normalized == "music"

      tag = Tag.find_or_create_by!(name: normalized, tag_type: "genre")
      Tagging.find_or_create_by!(
        tag: tag,
        taggable: @track,
        user: @track.user
      )
    end
  end

  def detect_language
    language = LanguageDetectorService.call(@track)
    @track.update!(language: language) if language.present?
  end

  def update_artist_storefront
    # The Apple Music service defaults to "us" storefront, so we don't
    # set it here — it would be misleading. The storefront is only useful
    # when we can determine the artist's primary market, which requires
    # checking multiple storefronts. For now, leave it nil.
  end

  def parse_release_year(release_date)
    return nil if release_date.blank?
    Date.parse(release_date).year
  rescue Date::Error
    nil
  end
end
