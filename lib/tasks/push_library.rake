namespace :library do
  desc "Push local music files to a remote Groovy Tunes instance"
  task :push do
    require "net/http"
    require "uri"
    require "json"

    remote_url = ENV.fetch("GROOVY_REMOTE_URL") { abort "GROOVY_REMOTE_URL is required" }
    client_id = ENV.fetch("GROOVY_CLIENT_ID") { abort "GROOVY_CLIENT_ID is required" }
    secret_key = ENV.fetch("GROOVY_SECRET_KEY") { abort "GROOVY_SECRET_KEY is required" }
    music_path = ENV.fetch("MUSIC_PATH", "/Volumes/music")

    token = authenticate(remote_url, client_id, secret_key)

    extensions = %w[mp3 flac ogg m4a aac wav wma opus webm]
    pattern = File.join(music_path, "**", "*.{#{extensions.join(",")}}")
    files = Dir.glob(pattern).sort

    if files.empty?
      puts "No audio files found in #{music_path}"
      exit
    end

    puts "Found #{files.size} audio files in #{music_path}"

    uri = URI.parse("#{remote_url}/api/import/tracks")

    created = 0
    existing = 0
    failed = 0

    files.each_with_index do |file_path, index|
      label = "[#{index + 1}/#{files.size}]"

      begin
        boundary = "----RubyMultipart#{SecureRandom.hex(16)}"

        file_name = File.basename(file_path)
        file_data = File.binread(file_path)

        body = build_multipart_body(boundary, file_name, file_data)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 30
        http.read_timeout = 300

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request["Authorization"] = "Bearer #{token}"
        request.body = body

        response = http.request(request)

        unless response.content_type&.include?("json")
          puts "#{label} #{file_name} — FAILED (#{response.code}: #{response.body[0..200]})"
          failed += 1
          next
        end

        json = JSON.parse(response.body)

        if response.code.to_i == 201
          puts "#{label} \"#{json["title"]}\" by #{json["artist"]} — created"
          created += 1
        elsif response.code.to_i == 200 && json["created"] == false
          puts "#{label} \"#{json["title"]}\" by #{json["artist"]} — exists"
          existing += 1
        else
          puts "#{label} #{file_name} — FAILED (#{response.code}: #{json["error"] || response.body})"
          failed += 1
        end
      rescue => e
        puts "#{label} #{File.basename(file_path)} — ERROR (#{e.message})"
        failed += 1
      end
    end

    puts
    puts "Done: #{created} created, #{existing} already existed, #{failed} failed"
  end
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

def build_multipart_body(boundary, file_name, file_data)
  body = +""
  body << "--#{boundary}\r\n"
  body << "Content-Disposition: form-data; name=\"audio_file\"; filename=\"#{file_name}\"\r\n"
  body << "Content-Type: application/octet-stream\r\n"
  body << "\r\n"
  body << file_data
  body << "\r\n"
  body << "--#{boundary}--\r\n"
  body
end
