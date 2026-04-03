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
    attrs = {
      apple_music_id: match[:apple_music_id],
      content_rating: match[:content_rating],
      enrichment_status: "matched",
      enriched_at: Time.current
    }

    attrs[:isrc] = match[:isrc] if @track.isrc.blank? && match[:isrc].present?
    attrs[:release_year] = parse_release_year(match[:release_date]) if @track.release_year.nil?

    @track.update!(attrs)

    detect_language
  end

  def detect_language
    return if @track.language.present?

    language = LanguageDetectorService.call(@track)
    @track.update!(language: language) if language.present?
  end

  def parse_release_year(release_date)
    return nil if release_date.blank?
    Date.parse(release_date).year
  rescue Date::Error
    nil
  end
end
