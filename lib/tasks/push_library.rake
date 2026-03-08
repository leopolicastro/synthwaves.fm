namespace :library do
  desc "Push local music files to a remote Groovy Tunes instance"
  task :push do
    require "net/http"
    require "uri"

    remote_url  = ENV.fetch("GROOVY_REMOTE_URL") { abort "GROOVY_REMOTE_URL is required" }
    remote_user = ENV.fetch("GROOVY_REMOTE_USER") { abort "GROOVY_REMOTE_USER is required" }
    remote_pass = ENV.fetch("GROOVY_REMOTE_PASSWORD") { abort "GROOVY_REMOTE_PASSWORD is required" }
    music_path  = ENV.fetch("MUSIC_PATH", "/Volumes/music")

    extensions = %w[mp3 flac ogg m4a aac wav wma opus webm]
    pattern = File.join(music_path, "**", "*.{#{extensions.join(',')}}")
    files = Dir.glob(pattern).sort

    if files.empty?
      puts "No audio files found in #{music_path}"
      exit
    end

    puts "Found #{files.size} audio files in #{music_path}"

    uri = URI.parse("#{remote_url}/api/import/tracks?u=#{CGI.escape(remote_user)}&p=#{CGI.escape(remote_pass)}")

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
        request.body = body

        response = http.request(request)
        json = JSON.parse(response.body)

        if response.code.to_i == 201
          puts "#{label} \"#{json['title']}\" by #{json['artist']} — created"
          created += 1
        elsif response.code.to_i == 200 && json["created"] == false
          puts "#{label} \"#{json['title']}\" by #{json['artist']} — exists"
          existing += 1
        else
          puts "#{label} #{file_name} — FAILED (#{response.code}: #{json['error'] || response.body})"
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
