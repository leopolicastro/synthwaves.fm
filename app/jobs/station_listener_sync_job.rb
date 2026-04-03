class StationListenerSyncJob < ApplicationJob
  ICECAST_STATUS_URL = "http://%{host}:%{port}/status-json.xsl"

  def perform
    stations = RadioStation.where(status: %w[active idle])
    return if stations.none?

    stats = fetch_icecast_stats
    return unless stats

    mount_listeners = parse_mount_listeners(stats)

    stations.find_each do |station|
      count = mount_listeners[station.mount_point] || 0
      next if station.listener_count == count

      station.update!(listener_count: count)
      station.broadcast_status
    end
  end

  private

  def fetch_icecast_stats
    host = ENV.fetch("ICECAST_INTERNAL_HOST", "localhost")
    port = ENV.fetch("ICECAST_INTERNAL_PORT", "8000")
    url = format(ICECAST_STATUS_URL, host: host, port: port)

    response = Net::HTTP.get_response(URI(url))
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue => e
    Rails.logger.warn("Failed to fetch Icecast stats: #{e.message}")
    nil
  end

  def parse_mount_listeners(stats)
    sources = stats.dig("icestats", "source")
    return {} unless sources

    # Icecast returns a single hash if one mount, array if multiple
    sources = [sources] if sources.is_a?(Hash)

    sources.each_with_object({}) do |source, result|
      mount = source["listenurl"]&.then { |url| URI(url).path }
      result[mount] = source["listeners"].to_i if mount
    end
  end
end
