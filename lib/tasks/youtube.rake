namespace :youtube do
  desc "Delete permanently failed YouTube tracks, reset stuck downloading tracks, clean up empty albums and artists"
  task cleanup: :environment do
    failed_tracks = Track.where.not(youtube_video_id: [nil, ""])
      .left_joins(:audio_file_attachment)
      .where(active_storage_attachments: {id: nil})
      .where(download_status: "failed")

    stuck_tracks = Track.where.not(youtube_video_id: [nil, ""])
      .left_joins(:audio_file_attachment)
      .where(active_storage_attachments: {id: nil})
      .where(download_status: "downloading")

    failed_count = failed_tracks.count
    stuck_count = stuck_tracks.count

    puts "Found #{failed_count} permanently failed tracks to delete"
    puts "Found #{stuck_count} stuck downloading tracks to reset"

    album_ids = failed_tracks.pluck(:album_id).uniq
    artist_ids = failed_tracks.pluck(:artist_id).uniq

    deleted = 0
    failed_tracks.find_each do |track|
      Rails.logger.info(
        "[YouTubeCleanup] Deleted track ##{track.id} \"#{track.title}\" " \
        "by \"#{track.artist.name}\" (youtube: #{track.youtube_video_id}) -- " \
        "reason: #{track.download_error.to_s.truncate(200)}"
      )
      track.destroy!
      deleted += 1
      print "\rDeleted #{deleted}/#{failed_count} tracks"
    end
    puts

    reset = stuck_tracks.update_all(download_status: nil, download_error: nil)
    puts "Reset #{reset} stuck tracks"

    empty_albums = Album.where(id: album_ids).left_joins(:tracks).where(tracks: {id: nil})
    albums_deleted = 0
    empty_albums.find_each do |album|
      Rails.logger.info("[YouTubeCleanup] Deleted empty album ##{album.id} \"#{album.title}\"")
      album.destroy!
      albums_deleted += 1
    end
    puts "Deleted #{albums_deleted} empty albums"

    empty_artists = Artist.where(id: artist_ids).left_joins(:tracks).where(tracks: {id: nil})
    artists_deleted = 0
    empty_artists.find_each do |artist|
      Rails.logger.info("[YouTubeCleanup] Deleted empty artist ##{artist.id} \"#{artist.name}\"")
      artist.destroy!
      artists_deleted += 1
    end
    puts "Deleted #{artists_deleted} empty artists"

    remaining = Track.where.not(youtube_video_id: [nil, ""])
      .left_joins(:audio_file_attachment)
      .where(active_storage_attachments: {id: nil})
      .count
    puts "\nDone. #{remaining} YouTube tracks still without audio (ready for retry)."
  end
end
