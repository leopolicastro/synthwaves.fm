class EPGSyncJob < ApplicationJob
  queue_as :default

  def perform
    EPGSyncService.call
  end
end
