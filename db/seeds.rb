# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user
admin = User.find_or_create_by!(email_address: "admin@example.com") do |u|
  u.password = "abc123"
  u.admin = true
end
puts "Admin user: admin@example.com / abc123"

def seed_album_dir(artist:, album_dir:)
  mp3_files = album_dir.glob("*.mp3").sort
  return 0 if mp3_files.empty?

  first_metadata = MetadataExtractor.call(mp3_files.first.to_s)

  album = Album.find_or_create_by!(title: album_dir.basename.to_s, artist: artist) do |a|
    a.year = first_metadata[:year]
    a.genre = first_metadata[:genre]
  end

  seeded = 0
  mp3_files.each do |mp3_path|
    metadata = MetadataExtractor.call(mp3_path.to_s)
    title = metadata[:title] || mp3_path.basename(".mp3").to_s.sub(/\A.*? - /, "")

    if Track.exists?(title: title, album: album, artist: artist)
      puts "  skip: #{title}"
      next
    end

    track = Track.create!(
      title: title,
      album: album,
      artist: artist,
      track_number: metadata[:track_number],
      disc_number: metadata[:disc_number] || 1,
      duration: metadata[:duration],
      bitrate: metadata[:bitrate],
      file_format: "mp3",
      file_size: File.size(mp3_path)
    )

    File.open(mp3_path) do |file|
      track.audio_file.attach(
        io: file,
        filename: mp3_path.basename.to_s,
        content_type: "audio/mpeg"
      )
    end

    if metadata[:cover_art] && !album.cover_image.attached?
      ext = metadata[:cover_art][:mime_type]&.split("/")&.last || "jpg"
      album.cover_image.attach(
        io: StringIO.new(metadata[:cover_art][:data]),
        filename: "cover.#{ext}",
        content_type: metadata[:cover_art][:mime_type] || "image/jpeg"
      )
    end

    seeded += 1
  end

  seeded
end

music_sources = [
  { artist: "Greta Van Fleet", path: "/Volumes/music/Greta Van Fleet" },
  { artist: "Eels", path: "/Volumes/music/Eels/Meet The EELS- Essential EELS 1996-2006 Vol. 1" }
]

total_tracks = 0

music_sources.each do |source|
  dir = Pathname.new(source[:path])
  unless dir.exist?
    puts "WARNING: #{dir} not found, skipping"
    next
  end

  artist = Artist.find_or_create_by!(name: source[:artist])

  # If the directory itself contains MP3s, treat it as a single album
  # Otherwise, iterate subdirectories as separate albums
  subdirs = dir.children.select(&:directory?).sort
  has_direct_mp3s = dir.glob("*.mp3").any?

  if has_direct_mp3s
    puts "Seeding album: #{dir.basename} by #{source[:artist]}"
    total_tracks += seed_album_dir(artist: artist, album_dir: dir)
  end

  subdirs.each do |album_dir|
    puts "Seeding album: #{album_dir.basename} by #{source[:artist]}"
    total_tracks += seed_album_dir(artist: artist, album_dir: album_dir)
  end
end

puts "Seeded #{Artist.count} artists, #{Album.count} albums, #{total_tracks} new tracks (#{Track.count} total)"

# Create a sample playlist from seeded tracks
playlist = Playlist.find_or_create_by!(name: "GVF Favorites", user: admin)
favorite_titles = ["Highway Tune", "Heat Above", "When The Curtain Falls", "Safari Song", "Black Smoke Rising"]
tracks = Track.where(title: favorite_titles)
tracks.each_with_index do |track, idx|
  PlaylistTrack.find_or_create_by!(playlist: playlist, track: track) do |pt|
    pt.position = idx + 1
  end
end

puts "Created playlist '#{playlist.name}' with #{playlist.tracks.count} tracks"
