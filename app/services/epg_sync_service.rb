class EPGSyncService
  EPG_URL = "https://tvpass.org/epg.xml"
  BATCH_SIZE = 500

  NETWORK_ERRORS = [
    HTTP::Error,
    HTTP::TimeoutError,
    SocketError,
    OpenSSL::SSL::SSLError,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    IO::TimeoutError
  ].freeze

  def self.call
    new.call
  end

  def self.sync_channel(channel)
    return 0 if channel.epg_url.blank? || channel.tvg_id.blank?

    new.sync_from_url(channel.epg_url, Set[channel.tvg_id], remap: [channel])
  end

  def call
    channels = IPTVChannel.where.not(tvg_id: [nil, ""])
    known_tvg_ids = channels.pluck(:tvg_id).to_set

    total_synced = 0
    synced_channel_ids = Set.new

    # Sync per-channel/custom EPG URLs first (grouped to avoid duplicate fetches)
    channels_with_epg = channels.where.not(epg_url: [nil, ""])
    channels_with_epg.group_by(&:epg_url).each do |url, grouped_channels|
      tvg_ids = grouped_channels.map(&:tvg_id).to_set
      count = sync_from_url(url, tvg_ids, remap: grouped_channels)
      total_synced += count
      synced_channel_ids.merge(tvg_ids)
    end

    # Sync remaining channels from global feed
    remaining_tvg_ids = known_tvg_ids - synced_channel_ids
    if remaining_tvg_ids.any?
      total_synced += sync_from_url(EPG_URL, remaining_tvg_ids)
    end

    Rails.logger.info("EPG sync complete: #{total_synced} programmes synced across #{known_tvg_ids.size} channels")

    {synced: total_synced, channels: known_tvg_ids.size}
  end

  def sync_from_url(url, tvg_ids, remap: nil)
    response = HTTP.follow(max_hops: 5).timeout(30).get(url)
    body = response.body.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    entries = XMLTVParser.parse(body)

    # For per-channel EPG URLs, the feed's channel IDs likely differ from our tvg_ids.
    # When a single channel has a custom URL, remap all feed entries to that channel.
    # When multiple channels share a URL, first try matching by tvg_id, then remap
    # unmatched entries if there's only one channel that got no matches.
    if remap
      feed_channel_ids = entries.map(&:channel_id).uniq
      matched_tvg_ids = tvg_ids & feed_channel_ids.to_set

      if matched_tvg_ids.empty? && remap.size == 1
        # Single channel, feed uses a different ID — remap all entries
        target_tvg_id = remap.first.tvg_id
        entries = entries.map do |e|
          XMLTVParser::ProgrammeEntry.new(**e.to_h.merge(channel_id: target_tvg_id))
        end
      end
    end

    relevant = entries.select { |e| tvg_ids.include?(e.channel_id) }
    return 0 if relevant.empty?

    now = Time.current
    records = relevant.map do |entry|
      {
        channel_id: entry.channel_id,
        title: entry.title,
        subtitle: entry.subtitle,
        description: entry.description,
        starts_at: entry.starts_at,
        ends_at: entry.ends_at,
        created_at: now,
        updated_at: now
      }
    end

    records.each_slice(BATCH_SIZE) do |batch|
      EPGProgramme.upsert_all(batch, unique_by: [:channel_id, :starts_at])
    end

    Rails.logger.info("EPG sync fetched #{records.size} programmes from #{url}")

    records.size
  rescue *NETWORK_ERRORS => e
    Rails.logger.warn("EPG sync failed for #{url}: #{e.message}")
    0
  end
end
