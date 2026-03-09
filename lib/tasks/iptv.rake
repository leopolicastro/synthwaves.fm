namespace :iptv do
  desc "Sync IPTV channels from iptv-org playlist"
  task sync: :environment do
    puts "Syncing IPTV channels..."
    result = IPTVChannelSyncService.call
    puts "Done. Synced #{result[:synced]} channels."
  end
end
