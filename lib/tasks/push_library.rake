namespace :library do
  desc "Push local music files to a remote synthwaves.fm instance"
  task push: :environment do
    require "net/http"
    require "uri"
    require "json"

    groovy = Rails.application.credentials.groovy
    abort "groovy credentials not configured" unless groovy

    remote_url = groovy[:url] || abort("groovy.url is required in credentials")
    client_id = groovy[:client_id] || abort("groovy.client_id is required in credentials")
    secret_key = groovy[:secret_key] || abort("groovy.secret_key is required in credentials")
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

      retries = 0
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

        if response.code.to_i == 503 && retries < 2
          retries += 1
          puts "#{label} #{file_name} — S3 error, retrying (#{retries}/2)..."
          sleep 2
          redo
        end

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
  body = +"".b
  body << "--#{boundary}\r\n".b
  body << "Content-Disposition: form-data; name=\"audio_file\"; filename=\"#{file_name}\"\r\n".b
  body << "Content-Type: application/octet-stream\r\n".b
  body << "\r\n".b
  body << file_data
  body << "\r\n".b
  body << "--#{boundary}--\r\n".b
  body
end
