class IcecastStatsService
  STATS_URL = "http://%{host}:%{port}/status-json.xsl"

  def self.listener_count(mount_point)
    new.listener_count(mount_point)
  end

  def self.all_mount_listeners
    new.all_mount_listeners
  end

  def listener_count(mount_point)
    all_mount_listeners&.fetch(mount_point, 0) || 0
  end

  # Returns nil when Icecast is unreachable, {} when up but no mounts active
  def all_mount_listeners
    stats = fetch_stats
    return nil unless stats

    parse_mount_listeners(stats)
  end

  private

  def fetch_stats
    host = ENV.fetch("ICECAST_INTERNAL_HOST", "localhost")
    port = ENV.fetch("ICECAST_INTERNAL_PORT", "8000")
    uri = URI(format(STATS_URL, host: host, port: port))

    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 2) do |http|
      http.get(uri.request_uri)
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue => e
    Rails.logger.warn("Failed to fetch Icecast stats: #{e.message}")
    nil
  end

  def parse_mount_listeners(stats)
    sources = stats.dig("icestats", "source")
    return {} unless sources

    sources = [sources] if sources.is_a?(Hash)

    sources.each_with_object({}) do |source, result|
      mount = source["listenurl"]&.then { |url| URI(url).path }
      result[mount] = source["listeners"].to_i if mount
    end
  end
end
