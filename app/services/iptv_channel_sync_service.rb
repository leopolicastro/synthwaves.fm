class IPTVChannelSyncService
  PLAYLIST_URL = "https://tvpass.org/playlist/m3u"
  BATCH_SIZE = 500

  def self.call
    new(PLAYLIST_URL, deactivate_missing: true).call
  end

  def self.import(url)
    new(url, deactivate_missing: false).call
  end

  def initialize(url, deactivate_missing: false)
    @url = url
    @deactivate_missing = deactivate_missing
  end

  def call
    Rails.logger.info "[IPTVSync] Starting sync from #{@url}"

    entries = fetch_and_parse
    imported, seen_tvg_ids = process_entries(entries)
    deactivate_missing_channels(seen_tvg_ids)
    reset_counter_caches

    Rails.logger.info "[IPTVSync] Done -- synced #{imported} channels (#{IPTVChannel.active.count} active)"

    {synced: imported}
  end

  private

  def fetch_and_parse
    response = HTTP.follow(max_hops: 5).timeout(connect: 10, read: 30).get(@url)
    body = response.body.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    entries = IPTVPlaylistParser.parse(body)
    Rails.logger.info "[IPTVSync] Parsed #{entries.size} entries"
    entries
  end

  def process_entries(entries)
    imported = 0
    seen_tvg_ids = Set.new
    batches = []

    entries.each do |entry|
      if entry.tvg_id.present?
        next if seen_tvg_ids.include?(entry.tvg_id)
        seen_tvg_ids << entry.tvg_id
        batches << build_record(entry)
      else
        create_without_tvg_id(entry)
      end

      imported += 1

      if batches.size >= BATCH_SIZE
        upsert_batch(batches)
        batches = []
      end
    end

    upsert_batch(batches) if batches.any?
    [imported, seen_tvg_ids]
  end

  def deactivate_missing_channels(seen_tvg_ids)
    return unless @deactivate_missing && seen_tvg_ids.any?
    IPTVChannel.where.not(tvg_id: [nil, ""] + seen_tvg_ids.to_a).update_all(active: false)
  end

  def build_record(entry)
    category = find_or_create_category(entry.group_title) if entry.group_title.present?

    {
      tvg_id: entry.tvg_id,
      name: entry.name,
      stream_url: entry.stream_url,
      logo_url: entry.logo_url,
      country: entry.country,
      language: entry.language,
      iptv_category_id: category&.id,
      active: true,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def create_without_tvg_id(entry)
    category = find_or_create_category(entry.group_title) if entry.group_title.present?

    IPTVChannel.find_or_create_by!(name: entry.name, stream_url: entry.stream_url) do |ch|
      ch.logo_url = entry.logo_url
      ch.country = entry.country
      ch.language = entry.language
      ch.iptv_category = category
    end
  rescue ActiveRecord::RecordInvalid
    # Skip invalid entries
  end

  def find_or_create_category(group_title)
    @categories_cache ||= {}
    @categories_cache[group_title] ||= IPTVCategory.find_or_create_by!(name: group_title)
  end

  def upsert_batch(records)
    IPTVChannel.upsert_all(
      records,
      unique_by: :tvg_id,
      update_only: [:name, :stream_url, :logo_url, :country, :language, :iptv_category_id, :active, :updated_at]
    )
  end

  def reset_counter_caches
    IPTVCategory.find_each do |category|
      IPTVCategory.reset_counters(category.id, :iptv_channels)
    end
  end
end
