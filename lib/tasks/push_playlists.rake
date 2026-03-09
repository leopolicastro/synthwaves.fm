namespace :playlists do
  desc "Push cliamp playlists to a remote SynthWaves.fm instance"
  task :push do
    require "net/http"
    require "uri"
    require "json"

    remote_url = ENV.fetch("GROOVY_REMOTE_URL") { abort "GROOVY_REMOTE_URL is required" }
    client_id = ENV.fetch("GROOVY_CLIENT_ID") { abort "GROOVY_CLIENT_ID is required" }
    secret_key = ENV.fetch("GROOVY_SECRET_KEY") { abort "GROOVY_SECRET_KEY is required" }
    playlists_path = ENV.fetch("CLIAMP_PLAYLISTS_PATH", File.expand_path("~/.config/cliamp/playlists"))

    token = authenticate(remote_url, client_id, secret_key)

    files = Dir.glob(File.join(playlists_path, "*.toml")).sort

    if files.empty?
      puts "No playlist files found in #{playlists_path}"
      exit
    end

    puts "Found #{files.size} playlist files in #{playlists_path}"

    uri = URI.parse("#{remote_url}/api/import/playlists")

    created = 0
    skipped_duplicate = 0
    skipped_empty = 0
    failed = 0

    files.each_with_index do |file_path, index|
      name = File.basename(file_path, ".toml")
      label = "[#{index + 1}/#{files.size}]"

      tracks = parse_toml_playlist(file_path)
      youtube_count = tracks.count { |t| !t[:path].start_with?("/") }
      local_tracks = tracks.select { |t| t[:path].start_with?("/") }

      if local_tracks.empty?
        puts "#{label} \"#{name}\" — skipped (no local tracks, #{youtube_count} YouTube)"
        skipped_empty += 1
        next
      end

      payload = {
        name: name,
        tracks: local_tracks.map { |t| {title: t[:title], artist: t[:artist], album: t[:album]} }
      }

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 15
        http.read_timeout = 30

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{token}"
        request.body = JSON.generate(payload)

        response = http.request(request)

        if response.code.to_i == 201
          json = JSON.parse(response.body)
          parts = ["#{json["tracks_matched"]} matched"]
          parts << "#{json["tracks_not_found"]} not found" if json["tracks_not_found"] > 0
          parts << "#{youtube_count} YouTube skipped" if youtube_count > 0
          puts "#{label} \"#{name}\" — created (#{parts.join(", ")})"
          created += 1
        elsif response.code.to_i == 409
          puts "#{label} \"#{name}\" — already exists"
          skipped_duplicate += 1
        else
          error = begin
            JSON.parse(response.body)["error"]
          rescue
            response.body[0..200]
          end
          puts "#{label} \"#{name}\" — FAILED (#{response.code}: #{error})"
          failed += 1
        end
      rescue => e
        puts "#{label} \"#{name}\" — ERROR (#{e.message})"
        failed += 1
      end
    end

    puts
    puts "Done: #{created} created, #{skipped_duplicate} duplicates skipped, #{skipped_empty} empty skipped, #{failed} failed"
  end
end

def parse_toml_playlist(path)
  tracks = []
  current = nil

  File.readlines(path).each do |line|
    line = line.strip
    if line == "[[track]]"
      tracks << current if current
      current = {}
    elsif current && line =~ /\A(\w+)\s*=\s*"(.*)"\z/
      current[$1.to_sym] = $2
    elsif current && line =~ /\A(\w+)\s*=\s*(\d+)\z/
      current[$1.to_sym] = $2.to_i
    end
  end
  tracks << current if current
  tracks
end

def authenticate(remote_url, client_id, secret_key)
  uri = URI.parse("#{remote_url}/api/v1/auth/token")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 15
  http.read_timeout = 15

  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(client_id: client_id, secret_key: secret_key)

  response = http.request(request)
  json = JSON.parse(response.body)

  unless response.code.to_i == 200 && json["token"]
    abort "Authentication failed: #{json["error"] || response.body}"
  end

  puts "Authenticated successfully"
  json["token"]
end
