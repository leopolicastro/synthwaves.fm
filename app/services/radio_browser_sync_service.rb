class RadioBrowserSyncService
  BATCH_SIZE = 500

  def initialize(country_code: nil, tag: nil, limit: 100)
    @country_code = country_code
    @tag = tag
    @limit = limit
  end

  def call
    api = RadioBrowserService.new
    entries = fetch_entries(api)

    imported = 0
    batches = []

    entries.each do |entry|
      next if entry["stationuuid"].blank?
      next if entry["url_resolved"].blank? && entry["url"].blank?

      batches << build_record(entry)
      imported += 1

      if batches.size >= BATCH_SIZE
        upsert_batch(batches)
        batches = []
      end
    end

    upsert_batch(batches) if batches.any?
    reset_counter_caches

    {synced: imported}
  end

  private

  def fetch_entries(api)
    if @country_code.present?
      api.by_country(@country_code, limit: @limit)
    elsif @tag.present?
      api.by_tag(@tag, limit: @limit)
    else
      api.top_voted(limit: @limit)
    end
  end

  def build_record(entry)
    category = find_or_create_category(entry["tags"]) if entry["tags"].present?

    {
      uuid: entry["stationuuid"],
      name: entry["name"].to_s.strip,
      stream_url: entry["url_resolved"].presence || entry["url"],
      homepage_url: entry["homepage"].presence,
      favicon_url: entry["favicon"].presence,
      country: entry["country"].presence,
      country_code: entry["countrycode"].presence,
      language: entry["language"].presence,
      tags: entry["tags"].presence,
      codec: entry["codec"].presence,
      bitrate: entry["bitrate"].to_i,
      votes: entry["votes"].to_i,
      internet_radio_category_id: category&.id,
      active: true,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def find_or_create_category(tags)
    primary_tag = tags.split(",").first.to_s.strip
    return nil if primary_tag.blank?

    @categories_cache ||= {}
    @categories_cache[primary_tag] ||= InternetRadioCategory.find_or_create_by!(name: primary_tag)
  end

  def upsert_batch(records)
    InternetRadioStation.upsert_all(
      records,
      unique_by: :uuid,
      update_only: %i[
        name stream_url homepage_url favicon_url country country_code
        language tags codec bitrate votes internet_radio_category_id active updated_at
      ]
    )
  end

  def reset_counter_caches
    InternetRadioCategory.find_each do |category|
      InternetRadioCategory.reset_counters(category.id, :internet_radio_stations)
    end
  end
end
