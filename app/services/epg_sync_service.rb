class EPGSyncService
  EPG_URL = "https://tvpass.org/epg.xml"
  BATCH_SIZE = 500

  def self.call
    new.call
  end

  def call
    response = HTTP.follow(max_hops: 5).get(EPG_URL)
    body = response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    entries = XMLTVParser.parse(body)

    known_tvg_ids = IPTVChannel.where.not(tvg_id: [nil, ""]).pluck(:tvg_id).to_set
    relevant_entries = entries.select { |e| known_tvg_ids.include?(e.channel_id) }

    # Delete current/future programmes for channels we're about to sync
    channel_ids_to_sync = relevant_entries.map(&:channel_id).uniq
    EPGProgramme.where(channel_id: channel_ids_to_sync).where("ends_at > ?", Time.current).delete_all

    # Insert in batches
    now = Time.current
    records = relevant_entries.map do |entry|
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
      EPGProgramme.insert_all(batch)
    end

    # Cleanup expired programmes (ended > 1 hour ago)
    EPGProgramme.where("ends_at < ?", 1.hour.ago).delete_all

    { synced: records.size, channels: channel_ids_to_sync.size }
  end
end
