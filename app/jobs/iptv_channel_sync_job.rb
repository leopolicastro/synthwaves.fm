class IPTVChannelSyncJob < ApplicationJob
  queue_as :default

  def perform
    IPTVChannelSyncService.call
  end
end
