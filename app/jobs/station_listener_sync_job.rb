class StationListenerSyncJob < ApplicationJob
  def perform
    return unless Flipper.enabled?(:radio_stations)

    stations = RadioStation.where(status: %w[active idle])
    return if stations.none?

    mount_listeners = IcecastStatsService.new.all_mount_listeners
    return if mount_listeners.nil?

    stations.find_each do |station|
      count = mount_listeners[station.mount_point] || 0
      next if station.listener_count == count

      station.update!(listener_count: count)
      station.broadcast_status
    end
  end
end
