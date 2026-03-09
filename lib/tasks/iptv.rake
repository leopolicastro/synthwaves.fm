namespace :iptv do
  desc "Sync IPTV channels from iptv-org playlist"
  task sync: :environment do
    puts "Syncing IPTV channels..."
    result = IPTVChannelSyncService.call
    puts "Done. Synced #{result[:synced]} channels."
  end

  desc "Sync EPG programme data from tvpass.org"
  task epg_sync: :environment do
    puts "Syncing EPG data..."
    result = EPGSyncService.call
    puts "Done. Synced #{result[:synced]} programmes across #{result[:channels]} channels."
  end
end
