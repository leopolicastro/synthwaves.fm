require_relative "remote_api"

namespace :library do
  desc "Push local music files to a remote synthwaves.fm instance via S3 direct upload"
  task push: :environment do
    require "digest"
    require "base64"

    synthwaves = Rails.application.credentials.synthwaves
    abort "synthwaves credentials not configured" unless synthwaves

    remote_url = synthwaves[:url] || abort("synthwaves.url is required in credentials")
    client_id = synthwaves[:client_id] || abort("synthwaves.client_id is required in credentials")
    secret_key = synthwaves[:secret_key] || abort("synthwaves.secret_key is required in credentials")
    music_path = File.expand_path(ENV.fetch("MUSIC_PATH", "~/Music"))
    exclude_path = File.expand_path(ENV.fetch("EXCLUDE_PATH", "~/Music/Music"))

    token = RemoteAPI.authenticate(remote_url, client_id, secret_key)
    token_issued_at = Time.now

    extensions = %w[mp3 flac ogg m4a aac wav wma opus webm]
    pattern = File.join(music_path, "**", "*.{#{extensions.join(",")}}")
    files = Dir.glob(pattern).sort
    files.reject! { |f| f.start_with?(exclude_path) } if exclude_path

    if files.empty?
      puts "No audio files found in #{music_path}"
      exit
    end

    puts "Found #{files.size} audio files in #{music_path}"

    created = 0
    existing = 0
    failed = 0
    deleted = 0

    mime_types = {
      "mp3" => "audio/mpeg", "flac" => "audio/flac", "ogg" => "audio/ogg",
      "m4a" => "audio/mp4", "aac" => "audio/aac", "wav" => "audio/wav",
      "wma" => "audio/x-ms-wma", "opus" => "audio/opus", "webm" => "audio/webm"
    }

    files.each_with_index do |file_path, index|
      label = "[#{index + 1}/#{files.size}]"
      file_name = File.basename(file_path)

      begin
        # Re-authenticate if token is older than 50 minutes
        if Time.now - token_issued_at > 3000
          puts "  Refreshing token..."
          token = RemoteAPI.authenticate(remote_url, client_id, secret_key)
          token_issued_at = Time.now
        end

        # 1. Extract metadata locally
        metadata = MetadataExtractor.call(file_path)

        # 2. Create blob via API
        file_size = File.size(file_path)
        checksum = Digest::MD5.file(file_path).base64digest
        file_format = File.extname(file_path).delete(".")
        content_type = mime_types.fetch(file_format, "application/octet-stream")

        blob = RemoteAPI.create_blob(remote_url, token, file_name, file_size, checksum, content_type)
        signed_id = blob["signed_id"]
        upload_url = blob.dig("direct_upload", "url")
        upload_headers = blob.dig("direct_upload", "headers")

        # 3. Upload directly to S3
        RemoteAPI.upload_to_s3(upload_url, upload_headers, file_path)

        # 4. Create track record with metadata
        track_params = {
          signed_blob_id: signed_id,
          title: metadata[:title],
          artist: metadata[:artist],
          album: metadata[:album],
          year: metadata[:year],
          genre: metadata[:genre],
          track_number: metadata[:track_number],
          disc_number: metadata[:disc_number],
          duration: metadata[:duration],
          bitrate: metadata[:bitrate],
          file_format: file_format
        }

        if metadata[:cover_art]
          track_params[:cover_art] = Base64.strict_encode64(metadata[:cover_art][:data])
          track_params[:cover_art_mime_type] = metadata[:cover_art][:mime_type]
        end

        response = create_track_record(remote_url, token, track_params)
        json = JSON.parse(response.body)

        if response.code.to_i == 201
          puts "#{label} \"#{json["title"]}\" by #{json["artist"]} — created"
          created += 1
          File.delete(file_path)
          deleted += 1
        elsif response.code.to_i == 200 && json["created"] == false
          puts "#{label} \"#{json["title"]}\" by #{json["artist"]} — exists, deleting local copy"
          existing += 1
          File.delete(file_path)
          deleted += 1
        else
          puts "#{label} #{file_name} — FAILED (#{response.code}: #{json["error"] || response.body})"
          failed += 1
        end
      rescue => e
        puts "#{label} #{file_name} — ERROR (#{e.message})"
        failed += 1
      end
    end

    # Remove empty directories left behind after file deletions
    dirs = files.map { |f| File.dirname(f) }.uniq.sort_by { |d| -d.length }
    dirs.each do |dir|
      while dir != music_path && Dir.exist?(dir) && (Dir.entries(dir) - %w[. ..]).empty?
        Dir.rmdir(dir)
        puts "Removed empty directory: #{dir}"
        dir = File.dirname(dir)
      end
    end

    puts
    puts "Done: #{created} created, #{existing} already existed, #{failed} failed, #{deleted} deleted locally"
  end
end

def create_track_record(remote_url, token, params)
  uri = URI.parse("#{remote_url}/api/import/tracks")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 15
  http.read_timeout = 30

  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{token}"
  request.body = JSON.generate(params)

  http.request(request)
end
