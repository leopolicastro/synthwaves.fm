# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user (configurable via ENV for self-hosting)
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "abc123")
admin = User.find_or_create_by!(email_address: admin_email) do |u|
  u.password = admin_password
  u.admin = true
end
puts "Admin user: #{admin_email} / #{admin_password}"

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
  {artist: "Greta Van Fleet", path: "/Volumes/music/Greta Van Fleet"},
  {artist: "Eels", path: "/Volumes/music/Eels/Meet The EELS- Essential EELS 1996-2006 Vol. 1"}
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

# Seed IPTV channels from tvpass.org
# Source: https://tvpass.org/playlist/m3u
# EPG: https://tvpass.org/epg.xml

tv_category = IPTVCategory.find_or_create_by!(name: "Live") do |c|
  c.slug = "live"
end

tvpass_channels = [
  {tvg_id: "ae-us-eastern-feed", name: "A&E US Eastern Feed", stream_url: "https://tvpass.org/live/AEEast/sd"},
  {tvg_id: "abc-kabc-los-angeles-ca", name: "ABC (KABC) Los Angeles", stream_url: "https://tvpass.org/live/abc-kabc-los-angeles-ca/sd"},
  {tvg_id: "abc-wabc-new-york-ny", name: "ABC (WABC) New York, NY", stream_url: "https://tvpass.org/live/WABCDT1/sd"},
  {tvg_id: "acc-network", name: "ACC Network", stream_url: "https://tvpass.org/live/ACCNetwork/sd"},
  {tvg_id: "altitude-sports-denver", name: "Altitude Sports Denver", stream_url: "https://tvpass.org/live/altitude-sports-denver/sd"},
  {tvg_id: "amc-eastern-feed", name: "AMC Eastern Feed", stream_url: "https://tvpass.org/live/AMCEast/sd"},
  {tvg_id: "american-heroes-channel", name: "American Heroes Channel", stream_url: "https://tvpass.org/live/AmericanHeroesChannel/sd"},
  {tvg_id: "animal-planet-us-east", name: "Animal Planet US East", stream_url: "https://tvpass.org/live/AnimalPlanetEast/sd"},
  {tvg_id: "bbc-america-east", name: "BBC America East", stream_url: "https://tvpass.org/live/BBCAmericaEast/sd"},
  {tvg_id: "bbc-news-north-america-hd", name: "BBC News North America HD", stream_url: "https://tvpass.org/live/BBCWorldNewsNorthAmerica/sd"},
  {tvg_id: "bet-eastern-feed", name: "BET Eastern Feed", stream_url: "https://tvpass.org/live/BETEast/sd"},
  {tvg_id: "bet-her", name: "BET Her", stream_url: "https://tvpass.org/live/BETHerEast/sd"},
  {tvg_id: "big-ten-network", name: "Big Ten Network", stream_url: "https://tvpass.org/live/BTN/sd"},
  {tvg_id: "bloomberg-tv-usa", name: "Bloomberg TV USA", stream_url: "https://tvpass.org/live/BloombergTV/sd"},
  {tvg_id: "boomerang", name: "Boomerang", stream_url: "https://tvpass.org/live/Boomerang/sd"},
  {tvg_id: "bravo-usa-eastern-feed", name: "Bravo USA Eastern Feed", stream_url: "https://tvpass.org/live/BravoEast/sd"},
  {tvg_id: "cspan", name: "C-SPAN", stream_url: "https://tvpass.org/live/CSPAN/sd"},
  {tvg_id: "cspan-2", name: "C-SPAN 2", stream_url: "https://tvpass.org/live/CSPAN2/sd"},
  {tvg_id: "cartoon-network-usa-eastern-feed", name: "Cartoon Network USA Eastern Feed", stream_url: "https://tvpass.org/live/CartoonNetworkEast/sd"},
  {tvg_id: "cbs-kcbs-los-angeles-ca", name: "CBS (KCBS) Los Angeles", stream_url: "https://tvpass.org/live/cbs-kcbs-los-angeles-ca/sd"},
  {tvg_id: "cbs-wcbs-new-york-ny", name: "CBS (WCBS) New York, NY", stream_url: "https://tvpass.org/live/WCBSDT1/sd"},
  {tvg_id: "cbs-sports-network-usa", name: "CBS Sports Network USA", stream_url: "https://tvpass.org/live/CBSSportsNetworkUSA/sd"},
  {tvg_id: "chicago-sports-network", name: "Chicago Sports Network", stream_url: "https://tvpass.org/live/chicago-sports-network/sd"},
  {tvg_id: "cinemax-eastern-feed", name: "Cinemax Eastern Feed", stream_url: "https://tvpass.org/live/CinemaxEast/sd"},
  {tvg_id: "cmt-us-eastern-feed", name: "CMT US Eastern Feed", stream_url: "https://tvpass.org/live/CMTEast/sd"},
  {tvg_id: "cnbc-usa", name: "CNBC USA", stream_url: "https://tvpass.org/live/CNBC/sd"},
  {tvg_id: "cnn", name: "CNN US", stream_url: "https://tvpass.org/live/CNN/sd"},
  {tvg_id: "comedy-central-us-eastern-feed", name: "Comedy Central (US) Eastern Feed", stream_url: "https://tvpass.org/live/ComedyCentralEast/sd"},
  {tvg_id: "crime-investigation-network-usa-hd", name: "Crime & Investigation Network USA HD", stream_url: "https://tvpass.org/live/CrimePlusInvestigation/sd"},
  {tvg_id: "cw-kfmbtv2-san-diego-ca", name: "CW (KFMB-TV2) San Diego", stream_url: "https://tvpass.org/live/cw-kfmbtv2-san-diego-ca/sd"},
  {tvg_id: "cw-wdcw-district-of-columbia", name: "CW (WDCW) District of Columbia", stream_url: "https://tvpass.org/live/cw-wdcw-district-of-columbia/sd"},
  {tvg_id: "destination-america", name: "Destination America", stream_url: "https://tvpass.org/live/DestinationAmerica/sd"},
  {tvg_id: "discovery-channel-us-eastern-feed", name: "Discovery Channel (US) Eastern Feed", stream_url: "https://tvpass.org/live/DiscoveryChannelEast/sd"},
  {tvg_id: "discovery-family-channel", name: "Discovery Family Channel", stream_url: "https://tvpass.org/live/DiscoveryFamily/sd"},
  {tvg_id: "discovery-life-channel", name: "Discovery Life Channel", stream_url: "https://tvpass.org/live/DiscoveryLife/sd"},
  {tvg_id: "disney-eastern-feed", name: "Disney Eastern Feed", stream_url: "https://tvpass.org/live/DisneyChannelEast/sd"},
  {tvg_id: "disney-junior-usa-east", name: "Disney Junior USA East", stream_url: "https://tvpass.org/live/DisneyJuniorEast/sd"},
  {tvg_id: "disney-xd-usa-eastern-feed", name: "Disney XD USA Eastern Feed", stream_url: "https://tvpass.org/live/DisneyXDEast/sd"},
  {tvg_id: "e-entertainment-usa-eastern-feed", name: "E! Entertainment USA Eastern Feed", stream_url: "https://tvpass.org/live/EEast/sd"},
  {tvg_id: "espn", name: "ESPN", stream_url: "https://tvpass.org/live/ESPN/sd"},
  {tvg_id: "espn-deportes", name: "ESPN Deportes", stream_url: "https://tvpass.org/live/espn-deportes/sd"},
  {tvg_id: "espn-news", name: "ESPN News", stream_url: "https://tvpass.org/live/ESPNews/sd"},
  {tvg_id: "espn-u", name: "ESPN U", stream_url: "https://tvpass.org/live/ESPNU/sd"},
  {tvg_id: "espn2", name: "ESPN2", stream_url: "https://tvpass.org/live/ESPN2/sd"},
  {tvg_id: "fanduel-sports-indiana", name: "Fanduel Sports Indiana", stream_url: "https://tvpass.org/live/fanduel-sports-indiana/sd"},
  {tvg_id: "fanduel-sports-network-detroit-hd", name: "Fanduel Sports Network Detroit", stream_url: "https://tvpass.org/live/fanduel-sports-network-detroit-hd/sd"},
  {tvg_id: "fanduel-sports-network-florida", name: "Fanduel Sports Network Florida", stream_url: "https://tvpass.org/live/fanduel-sports-network-florida/sd"},
  {tvg_id: "fanduel-sports-network-great-lakes", name: "Fanduel Sports Network Great Lakes", stream_url: "https://tvpass.org/live/fanduel-sports-network-great-lakes/sd"},
  {tvg_id: "fanduel-sports-network-north", name: "Fanduel Sports Network North", stream_url: "https://tvpass.org/live/fanduel-sports-network-north/sd"},
  {tvg_id: "fanduel-sports-network-ohio-cleveland", name: "Fanduel Sports Network Ohio Cleveland", stream_url: "https://tvpass.org/live/fanduel-sports-network-ohio-cleveland/sd"},
  {tvg_id: "fanduel-sports-network-oklahoma", name: "Fanduel Sports Network Oklahoma", stream_url: "https://tvpass.org/live/fanduel-sports-network-oklahoma/sd"},
  {tvg_id: "fanduel-sports-network-san-diego", name: "Fanduel Sports Network San Diego", stream_url: "https://tvpass.org/live/fanduel-sports-network-san-diego/sd"},
  {tvg_id: "fanduel-sports-network-socal", name: "Fanduel Sports Network Socal", stream_url: "https://tvpass.org/live/fanduel-sports-network-socal/sd"},
  {tvg_id: "fanduel-sports-network-south-carolinas", name: "Fanduel Sports Network South Carolinas", stream_url: "https://tvpass.org/live/fanduel-sports-network-south-carolinas/sd"},
  {tvg_id: "fanduel-sports-network-south-tennessee-usa", name: "Fanduel Sports Network South Tennessee", stream_url: "https://tvpass.org/live/fanduel-sports-network-south-tennessee-usa/sd"},
  {tvg_id: "fanduel-sports-network-west", name: "Fanduel Sports Network West", stream_url: "https://tvpass.org/live/fanduel-sports-network-west/sd"},
  {tvg_id: "fanduel-sports-network-wisconsin", name: "Fanduel Sports Network Wisconsin", stream_url: "https://tvpass.org/live/fanduel-sports-network-wisconsin/sd"},
  {tvg_id: "fanduel-sports-southeast-georgia", name: "Fanduel Sports Southeast Georgia", stream_url: "https://tvpass.org/live/fanduel-sports-southeast-georgia/sd"},
  {tvg_id: "fanduel-sports-southeast-north-carolina", name: "Fanduel Sports Southeast North Carolina", stream_url: "https://tvpass.org/live/fanduel-sports-southeast-north-carolina/sd"},
  {tvg_id: "fanduel-sports-southeast-south-carolina", name: "Fanduel Sports Southeast South Carolina", stream_url: "https://tvpass.org/live/fanduel-sports-southeast-south-carolina/sd"},
  {tvg_id: "fanduel-sports-southeast-tennessee-nashville", name: "Fanduel Sports Southeast Tennessee Nashville", stream_url: "https://tvpass.org/live/fanduel-sports-southeast-tennessee-nashville/sd"},
  {tvg_id: "bally-sports-sun", name: "Fanduel Sports Sun", stream_url: "https://tvpass.org/live/fanduel-sports-sun/sd"},
  {tvg_id: "fanduel-sports-tennessee-east", name: "Fanduel Sports Tennessee East", stream_url: "https://tvpass.org/live/fanduel-sports-tennessee-east/sd"},
  {tvg_id: "food-network-usa-eastern-feed", name: "Food Network USA Eastern Feed", stream_url: "https://tvpass.org/live/FoodNetworkEast/sd"},
  {tvg_id: "fox-kttv-los-angeles-ca", name: "FOX (KTTV) Los Angeles", stream_url: "https://tvpass.org/live/fox-kttv-los-angeles-ca/sd"},
  {tvg_id: "fox-wnyw-new-york-ny", name: "FOX (WNYW) New York, NY", stream_url: "https://tvpass.org/live/WNYWDT1/sd"},
  {tvg_id: "fox-business", name: "Fox Business", stream_url: "https://tvpass.org/live/FoxBusiness/sd"},
  {tvg_id: "fox-news", name: "Fox News", stream_url: "https://tvpass.org/live/FoxNewsChannel/sd"},
  {tvg_id: "fox-sports-1", name: "Fox Sports 1", stream_url: "https://tvpass.org/live/FoxSports1/sd"},
  {tvg_id: "fox-sports-2", name: "Fox Sports 2", stream_url: "https://tvpass.org/live/FoxSports2/sd"},
  {tvg_id: "freeform-east-feed", name: "Freeform East Feed", stream_url: "https://tvpass.org/live/FreeformEast/sd"},
  {tvg_id: "fuse-tv-eastern-feed", name: "FUSE TV Eastern feed", stream_url: "https://tvpass.org/live/FuseEast/sd"},
  {tvg_id: "fx-movie-channel", name: "FX Movie Channel", stream_url: "https://tvpass.org/live/FXMovieChannel/sd"},
  {tvg_id: "fx-networks-east-coast", name: "FX Networks East Coast", stream_url: "https://tvpass.org/live/FXEast/sd"},
  {tvg_id: "fxx-usa-eastern", name: "FXX USA Eastern", stream_url: "https://tvpass.org/live/FXXEast/sd"},
  {tvg_id: "fyi-usa-eastern", name: "FYI USA Eastern", stream_url: "https://tvpass.org/live/FYIEast/sd"},
  {tvg_id: "game-show-network-east", name: "Game Show Network East", stream_url: "https://tvpass.org/live/game-show-network-east/sd"},
  {tvg_id: "golf-channel-usa", name: "Golf Channel USA", stream_url: "https://tvpass.org/live/GolfChannel/sd"},
  {tvg_id: "hallmark-eastern-feed", name: "Hallmark Eastern Feed", stream_url: "https://tvpass.org/live/HallmarkChannelEast/sd"},
  {tvg_id: "hallmark-family-hd", name: "Hallmark Family HD", stream_url: "https://tvpass.org/live/HallmarkDrama/sd"},
  {tvg_id: "hallmark-mystery-eastern-hd", name: "Hallmark Mystery Eastern HD", stream_url: "https://tvpass.org/live/HallmarkMoviesMysteriesEast/sd"},
  {tvg_id: "hbo-eastern-feed", name: "HBO Eastern Feed", stream_url: "https://tvpass.org/live/HBOEast/sd"},
  {tvg_id: "hbo-2-eastern-feed", name: "HBO 2 Eastern Feed", stream_url: "https://tvpass.org/live/HBO2East/sd"},
  {tvg_id: "hbo-comedy-hd-east", name: "HBO Comedy HD East", stream_url: "https://tvpass.org/live/HBOComedyEast/sd"},
  {tvg_id: "hbo-family-eastern-feed", name: "HBO Family Eastern Feed", stream_url: "https://tvpass.org/live/HBOFamilyEast/sd"},
  {tvg_id: "hbo-signature-hbo-3-eastern", name: "HBO Signature (HBO 3) Eastern", stream_url: "https://tvpass.org/live/HBOSignatureEast/sd"},
  {tvg_id: "hbo-zone-hd-east", name: "HBO Zone HD East", stream_url: "https://tvpass.org/live/HBOZoneEast/sd"},
  {tvg_id: "hgtv-usa-eastern-feed", name: "HGTV USA Eastern Feed", stream_url: "https://tvpass.org/live/HGTVEast/sd"},
  {tvg_id: "history-channel-us-eastern-feed", name: "History Channel US Eastern Feed", stream_url: "https://tvpass.org/live/HistoryEast/sd"},
  {tvg_id: "hln", name: "HLN", stream_url: "https://tvpass.org/live/HLN/sd"},
  {tvg_id: "independent-film-channel-us", name: "Independent Film Channel US", stream_url: "https://tvpass.org/live/IFCEast/sd"},
  {tvg_id: "investigation-discovery-usa-eastern", name: "Investigation Discovery USA Eastern", stream_url: "https://tvpass.org/live/InvestigationDiscoveryEast/sd"},
  {tvg_id: "ion-eastern-feed", name: "ION Eastern Feed", stream_url: "https://tvpass.org/live/IONTVEast/sd"},
  {tvg_id: "lifetime-movies-east", name: "Lifetime Movies East", stream_url: "https://tvpass.org/live/LifetimeMoviesEast/sd"},
  {tvg_id: "lifetime-network-us-eastern-feed", name: "Lifetime Network US Eastern Feed", stream_url: "https://tvpass.org/live/LifetimeEast/sd"},
  {tvg_id: "logo-east", name: "LOGO East", stream_url: "https://tvpass.org/live/LogoEast/sd"},
  {tvg_id: "marquee-sports-network", name: "Marquee Sports Network", stream_url: "https://tvpass.org/live/marquee-sports-network/sd"},
  {tvg_id: "metv-toons-wjlp2-new-jersey", name: "MeTV Toons (WJLP2) New Jersey", stream_url: "https://tvpass.org/live/metv-toons/sd"},
  {tvg_id: "metv-wjlp-new-jerseynew-york", name: "MeTV Wjlp New Jerseynew York", stream_url: "https://tvpass.org/live/metv-wjlp-new-jerseynew-york/sd"},
  {tvg_id: "midatlantic-sports-network", name: "Midatlantic Sports Network", stream_url: "https://tvpass.org/live/midatlantic-sports-network/sd"},
  {tvg_id: "mlb-network", name: "MLB Network", stream_url: "https://tvpass.org/live/MLBNetwork/sd"},
  {tvg_id: "monumental-sports-network", name: "Monumental Sports Network", stream_url: "https://tvpass.org/live/monumental-sports-network/sd"},
  {tvg_id: "moremax-eastern", name: "MoreMax Eastern", stream_url: "https://tvpass.org/live/MoreMaxEast/sd"},
  {tvg_id: "motor-trend-hd", name: "Motor Trend HD", stream_url: "https://tvpass.org/live/Motortrend/sd"},
  {tvg_id: "moviemax-max-6-east", name: "MovieMax (Max 6) East", stream_url: "https://tvpass.org/live/MovieMaxEast/sd"},
  {tvg_id: "msg-madison-square-gardens", name: "MSG Madison Square Gardens", stream_url: "https://tvpass.org/live/msg-madison-square-gardens/sd"},
  {tvg_id: "msg-plus", name: "MSG Plus", stream_url: "https://tvpass.org/live/msg-plus/sd"},
  {tvg_id: "msnbc-usa", name: "MSNBC USA", stream_url: "https://tvpass.org/live/MSNBC/sd"},
  {tvg_id: "mtv-2-east", name: "MTV 2 East", stream_url: "https://tvpass.org/live/mtv-2-east/sd"},
  {tvg_id: "mtv-usa-eastern-feed", name: "MTV USA Eastern Feed", stream_url: "https://tvpass.org/live/MTVEast/sd"},
  {tvg_id: "national-geographic-us-eastern", name: "National Geographic US Eastern", stream_url: "https://tvpass.org/live/NationalGeographicEast/sd"},
  {tvg_id: "national-geographic-wild", name: "National Geographic Wild", stream_url: "https://tvpass.org/live/NationalGeographicWildEast/sd"},
  {tvg_id: "nba-tv-usa", name: "NBA TV USA", stream_url: "https://tvpass.org/live/NBATV/sd"},
  {tvg_id: "nbc-knbc-los-angeles-ca", name: "NBC (KNBC) Los Angeles", stream_url: "https://tvpass.org/live/nbc-knbc-los-angeles-ca/sd"},
  {tvg_id: "nbc-wnbc-new-york-ny", name: "NBC (WNBC) New York, NY", stream_url: "https://tvpass.org/live/WNBCDT1/sd"},
  {tvg_id: "nbc-sports-bay-area", name: "NBC Sports Bay Area", stream_url: "https://tvpass.org/live/nbc-sports-bay-area/sd"},
  {tvg_id: "nbc-sports-boston", name: "NBC Sports Boston", stream_url: "https://tvpass.org/live/nbc-sports-boston/sd"},
  {tvg_id: "nbc-sports-california", name: "NBC Sports California", stream_url: "https://tvpass.org/live/nbc-sports-california/sd"},
  {tvg_id: "nbc-sports-philadelphia", name: "NBC Sports Philadelphia", stream_url: "https://tvpass.org/live/nbc-sports-philadelphia/sd"},
  {tvg_id: "new-england-sports-network", name: "New England Sports Network", stream_url: "https://tvpass.org/live/new-england-sports-network/sd"},
  {tvg_id: "newsmax-tv", name: "NewsMax TV", stream_url: "https://tvpass.org/live/NewsmaxTV/sd"},
  {tvg_id: "nfl-network", name: "NFL Network", stream_url: "https://tvpass.org/live/NFLNetwork/sd"},
  {tvg_id: "nfl-redzone", name: "NFL RedZone", stream_url: "https://tvpass.org/live/NFLRedZone/sd"},
  {tvg_id: "nhl-network-usa", name: "NHL Network USA", stream_url: "https://tvpass.org/live/NHLNetwork/sd"},
  {tvg_id: "nick-jr-east", name: "Nick Jr. East", stream_url: "https://tvpass.org/live/NickJrEast/sd"},
  {tvg_id: "nickelodeon-usa-east-feed", name: "Nickelodeon USA East Feed", stream_url: "https://tvpass.org/live/NickelodeonEast/sd"},
  {tvg_id: "nicktoons-east", name: "Nicktoons East", stream_url: "https://tvpass.org/live/NicktoonsEast/sd"},
  {tvg_id: "oprah-winfrey-network-usa-eastern", name: "Oprah Winfrey Network USA Eastern", stream_url: "https://tvpass.org/live/OWNEast/sd"},
  {tvg_id: "outdoor-channel-us", name: "Outdoor Channel US", stream_url: "https://tvpass.org/live/OutdoorChannel/sd"},
  {tvg_id: "oxygen-eastern-feed", name: "Oxygen Eastern Feed", stream_url: "https://tvpass.org/live/OxygenEast/sd"},
  {tvg_id: "pbs-wnet-new-york-ny", name: "PBS (WNET) New York, NY", stream_url: "https://tvpass.org/live/WNET/sd"},
  {tvg_id: "reelzchannel", name: "ReelzChannel", stream_url: "https://tvpass.org/live/Reelz/sd"},
  {tvg_id: "science", name: "Science", stream_url: "https://tvpass.org/live/Science/sd"},
  {tvg_id: "sec-network", name: "SEC Network", stream_url: "https://tvpass.org/live/SECN/sd"},
  {tvg_id: "paramount-with-showtime-eastern-feed", name: "Showtime Eastern Feed", stream_url: "https://tvpass.org/live/ShowtimeEast/sd"},
  {tvg_id: "showtime-2-eastern", name: "Showtime 2 Eastern", stream_url: "https://tvpass.org/live/Showtime2East/sd"},
  {tvg_id: "sny-sportsnet-new-york-comcast", name: "SNY Sportsnet New York Comcast", stream_url: "https://tvpass.org/live/sny-sportsnet-new-york-comcast/sd"},
  {tvg_id: "space-city-home-network", name: "Space City Home Network", stream_url: "https://tvpass.org/live/space-city-home-network/sd"},
  {tvg_id: "spectrum-sportsnet-la", name: "Spectrum SportsNet LA", stream_url: "https://tvpass.org/live/spectrum-sportsnet-la/sd"},
  {tvg_id: "spectrum-sportsnet", name: "Spectrum Sportsnet Lakers", stream_url: "https://tvpass.org/live/spectrum-sportsnet/sd"},
  {tvg_id: "sportsnet-east", name: "Sportsnet (East)", stream_url: "https://tvpass.org/live/sportsnet-east/sd"},
  {tvg_id: "sportsnet-360", name: "Sportsnet 360", stream_url: "https://tvpass.org/live/sportsnet-360/sd"},
  {tvg_id: "sportsnet-one", name: "Sportsnet One", stream_url: "https://tvpass.org/live/sportsnet-one/sd"},
  {tvg_id: "sportsnet-ontario", name: "Sportsnet Ontario", stream_url: "https://tvpass.org/live/sportsnet-ontario/sd"},
  {tvg_id: "sportsnet-pacific", name: "Sportsnet Pacific", stream_url: "https://tvpass.org/live/sportsnet-pacific/sd"},
  {tvg_id: "sportsnet-pittsburgh", name: "Sportsnet Pittsburgh", stream_url: "https://tvpass.org/live/sportsnet-pittsburgh/sd"},
  {tvg_id: "sportsnet-west", name: "Sportsnet West", stream_url: "https://tvpass.org/live/sportsnet-west/sd"},
  {tvg_id: "starz-eastern", name: "Starz Eastern", stream_url: "https://tvpass.org/live/StarzEast/sd"},
  {tvg_id: "sundancetv-usa-east", name: "SundanceTV USA East", stream_url: "https://tvpass.org/live/SundanceTVEast/sd"},
  {tvg_id: "syfy-eastern-feed", name: "Syfy Eastern Feed", stream_url: "https://tvpass.org/live/SyfyEast/sd"},
  {tvg_id: "tbs-east", name: "TBS East", stream_url: "https://tvpass.org/live/TBSEast/sd"},
  {tvg_id: "teennick-eastern", name: "TeenNick Eastern", stream_url: "https://tvpass.org/live/TeenNickEast/sd"},
  {tvg_id: "telemundo-eastern-feed", name: "Telemundo Eastern Feed", stream_url: "https://tvpass.org/live/TelemundoEast/sd"},
  {tvg_id: "the-cooking-channel", name: "The Cooking Channel", stream_url: "https://tvpass.org/live/CookingChannel/sd"},
  {tvg_id: "the-tennis-channel", name: "The Tennis Channel", stream_url: "https://tvpass.org/live/TennisChannel/sd"},
  {tvg_id: "the-weather-channel", name: "The Weather Channel", stream_url: "https://tvpass.org/live/TheWeatherChannel/sd"},
  {tvg_id: "tlc-usa-eastern", name: "TLC USA Eastern", stream_url: "https://tvpass.org/live/TLCEast/sd"},
  {tvg_id: "tmc-us-eastern-feed", name: "TMC (US) Eastern Feed", stream_url: "https://tvpass.org/live/TheMovieChannelEast/sd"},
  {tvg_id: "tnt-eastern-feed", name: "TNT Eastern Feed", stream_url: "https://tvpass.org/live/TNTEast/sd"},
  {tvg_id: "travel-us-east", name: "Travel US East", stream_url: "https://tvpass.org/live/TravelChannelEast/sd"},
  {tvg_id: "trutv-usa-eastern", name: "truTV USA Eastern", stream_url: "https://tvpass.org/live/truTVEast/sd"},
  {tvg_id: "tsn1", name: "TSN1", stream_url: "https://tvpass.org/live/tsn1/sd"},
  {tvg_id: "tsn2", name: "TSN2", stream_url: "https://tvpass.org/live/tsn2/sd"},
  {tvg_id: "tsn3", name: "TSN3", stream_url: "https://tvpass.org/live/tsn3/sd"},
  {tvg_id: "tsn4", name: "TSN4", stream_url: "https://tvpass.org/live/tsn4/sd"},
  {tvg_id: "tsn5", name: "TSN5", stream_url: "https://tvpass.org/live/tsn5/sd"},
  {tvg_id: "turner-classic-movies-usa", name: "Turner Classic Movies USA", stream_url: "https://tvpass.org/live/TCMEast/sd"},
  {tvg_id: "tv-land-eastern", name: "TV Land Eastern", stream_url: "https://tvpass.org/live/tv-land-eastern/sd"},
  {tvg_id: "tv-one", name: "TV One", stream_url: "https://tvpass.org/live/TVOne/sd"},
  {tvg_id: "universal-kids", name: "Universal Kids", stream_url: "https://tvpass.org/live/UniversalKidsEast/sd"},
  {tvg_id: "univision-eastern-feed", name: "Univision Eastern Feed", stream_url: "https://tvpass.org/live/UnivisionEast/sd"},
  {tvg_id: "usa-network-east-feed", name: "USA Network East Feed", stream_url: "https://tvpass.org/live/USANetworkEast/sd"},
  {tvg_id: "vh1-eastern-feed", name: "VH1 Eastern Feed", stream_url: "https://tvpass.org/live/VH1East/sd"},
  {tvg_id: "vice", name: "VICE", stream_url: "https://tvpass.org/live/VICETV/sd"},
  {tvg_id: "we-womens-entertainment-eastern", name: "WE (Women's Entertainment) Eastern", stream_url: "https://tvpass.org/live/WeTVEast/sd"},
  {tvg_id: "wpix-new-york-superstation", name: "WPIX New York (SUPERSTATION)", stream_url: "https://tvpass.org/live/WPIX/sd"},
  {tvg_id: "yes-network", name: "Yes Network", stream_url: "https://tvpass.org/live/yes-network/sd"}
]

seeded_channels = 0
tvpass_channels.each do |ch|
  IPTVChannel.find_or_create_by!(tvg_id: ch[:tvg_id]) do |channel|
    channel.name = ch[:name]
    channel.stream_url = ch[:stream_url]
    channel.iptv_category = tv_category
    channel.country = "US"
    channel.active = true
  end
  seeded_channels += 1
end

puts "Seeded #{seeded_channels} IPTV channels in '#{tv_category.name}' category (#{IPTVChannel.count} total)"
