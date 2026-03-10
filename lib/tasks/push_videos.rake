require_relative "remote_api"

namespace :videos do
  desc "Encode (if needed) and push a video to a remote synthwaves.fm instance via S3 direct upload"
  task push: :environment do
    require "digest"
    require "base64"
    require "open3"

    groovy = Rails.application.credentials.groovy
    abort "groovy credentials not configured" unless groovy

    remote_url = groovy[:url] || abort("groovy.url is required in credentials")
    client_id = groovy[:client_id] || abort("groovy.client_id is required in credentials")
    secret_key = groovy[:secret_key] || abort("groovy.secret_key is required in credentials")
    input_path = ENV.fetch("VIDEO") { abort "VIDEO is required (path to video file or directory)" }
    abort "Not found: #{input_path}" unless File.exist?(input_path)

    folder_name = ENV["FOLDER"]
    video_extensions = %w[mp4 mkv avi mov m4v wmv flv webm ts]

    # Collect video files — single file or recursive directory scan
    if File.directory?(input_path)
      pattern = File.join(input_path, "**", "*.{#{video_extensions.join(",")}}")
      video_files = Dir.glob(pattern).sort
      abort "No video files found in #{input_path}" if video_files.empty?
      puts "Found #{video_files.size} video files in #{input_path}"
    else
      video_files = [input_path]
    end

    # Authenticate and re-authenticate before token expires
    puts "Authenticating..."
    token = RemoteAPI.authenticate(remote_url, client_id, secret_key)
    token_issued_at = Time.now

    uploaded = 0
    failed = 0

    video_files.each_with_index do |video_path, index|
      temp_file = nil
      label = video_files.size > 1 ? "[#{index + 1}/#{video_files.size}] " : ""

      begin
        # Re-authenticate if token is older than 50 minutes
        if Time.now - token_issued_at > 3000
          puts "  Refreshing token..."
          token = RemoteAPI.authenticate(remote_url, client_id, secret_key)
          token_issued_at = Time.now
        end

        title = ENV.fetch("TITLE", File.basename(video_path, File.extname(video_path)))
        season_number = ENV["SEASON"]
        episode_number = ENV["EPISODE"]

        # 1. Probe input
        puts "#{label}Probing #{File.basename(video_path)}..."
        probe = probe_video(video_path)
        strategy = encoding_strategy(probe, video_path)
        puts "  Video: #{probe[:video_codec]}, Audio: #{probe[:audio_codec]}, Container: #{probe[:container]}"
        puts "  Strategy: #{strategy}"

        # 2. Encode if needed
        upload_path = video_path

        case strategy
        when :remux
          temp_file = "#{video_path}.remuxed.mp4"
          puts "  Remuxing to MP4 with faststart..."
          remux(video_path, temp_file)
          upload_path = temp_file
        when :full
          temp_file = "#{video_path}.encoded.mp4"
          puts "  Encoding with h264_videotoolbox..."
          encode(video_path, temp_file)
          upload_path = temp_file
        else
          puts "  Already H264+AAC+MP4 — uploading original"
        end

        # 3. Create blob via API
        file_size = File.size(upload_path)
        checksum = Digest::MD5.file(upload_path).base64digest
        filename = "#{File.basename(video_path, File.extname(video_path))}.mp4"

        puts "  Creating blob (#{(file_size / 1024.0 / 1024.0).round(1)} MB)..."
        blob_response = RemoteAPI.create_blob(remote_url, token, filename, file_size, checksum, "video/mp4")

        signed_id = blob_response["signed_id"]
        upload_url = blob_response.dig("direct_upload", "url")
        upload_headers = blob_response.dig("direct_upload", "headers")

        # 4. Upload to S3
        puts "  Uploading to S3..."
        RemoteAPI.upload_to_s3(upload_url, upload_headers, upload_path)
        puts "  Upload complete"

        # 5. Create video record
        puts "  Creating video record..."
        video = create_video_record(remote_url, token, signed_id, title, folder_name, season_number, episode_number)
        puts "  Created: \"#{video["title"]}\" (id: #{video["id"]}, status: #{video["status"]})"

        # 6. Move original to _uploaded on the volume root
        volume_root = if video_path.start_with?("/Volumes/")
          File.join("/Volumes", video_path.split("/")[2])
        else
          File.dirname(video_path)
        end
        uploaded_dir = File.join(volume_root, "_uploaded")
        FileUtils.mkdir_p(uploaded_dir)
        dest = File.join(uploaded_dir, File.basename(video_path))
        FileUtils.mv(video_path, dest)
        puts "  Moved to #{dest}"

        uploaded += 1
      rescue => e
        puts "  ERROR: #{e.message}"
        failed += 1
      ensure
        if temp_file && File.exist?(temp_file)
          FileUtils.rm_f(temp_file)
        end
      end
    end

    puts
    puts "Done! #{uploaded} uploaded, #{failed} failed."
  end
end

def probe_video(path)
  cmd = [
    "ffprobe", "-v", "quiet", "-print_format", "json",
    "-show_streams", "-show_format", path
  ]
  stdout, status = Open3.capture2(*cmd)
  abort "ffprobe failed for #{path}" unless status.success?

  data = JSON.parse(stdout)
  video_stream = data["streams"]&.find { |s| s["codec_type"] == "video" }
  audio_stream = data["streams"]&.find { |s| s["codec_type"] == "audio" }
  format_name = data.dig("format", "format_name") || ""

  {
    video_codec: video_stream&.dig("codec_name"),
    audio_codec: audio_stream&.dig("codec_name"),
    container: format_name
  }
end

def encoding_strategy(probe, path)
  h264 = probe[:video_codec] == "h264"
  aac = probe[:audio_codec]&.match?(/aac/)
  mp4 = probe[:container]&.match?(/mp4|mov|m4v/)

  if h264 && aac && mp4 && faststart?(path)
    :none
  elsif h264 && aac && mp4
    :remux
  elsif h264 && aac
    :remux
  else
    :full
  end
end

def faststart?(path)
  # Check if moov atom is before mdata — a hallmark of faststart
  stdout, = Open3.capture2(
    "ffprobe", "-v", "trace", "-i", path,
    err: [:child, :out]
  )
  moov_pos = stdout.index("moov")
  mdat_pos = stdout.index("mdat")
  moov_pos && mdat_pos && moov_pos < mdat_pos
end

def remux(input, output)
  success = system(
    "ffmpeg", "-y", "-i", input,
    "-c", "copy",
    "-movflags", "+faststart",
    output
  )
  abort "ffmpeg remux failed" unless success
end

def encode(input, output)
  success = system(
    "ffmpeg", "-y", "-i", input,
    "-c:v", "h264_videotoolbox", "-q:v", "65", "-allow_sw", "1",
    "-c:a", "aac", "-b:a", "128k",
    "-movflags", "+faststart",
    "-tag:v", "avc1",
    output
  )
  abort "ffmpeg encode failed" unless success
end

def create_video_record(remote_url, token, signed_blob_id, title, folder_name, season_number, episode_number)
  uri = URI.parse("#{remote_url}/api/import/videos")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 15
  http.read_timeout = 30

  body = { signed_blob_id: signed_blob_id, title: title }
  body[:folder_name] = folder_name if folder_name
  body[:season_number] = season_number.to_i if season_number
  body[:episode_number] = episode_number.to_i if episode_number

  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{token}"
  request.body = JSON.generate(body)

  response = http.request(request)

  unless response.code.to_i == 201
    abort "Video creation failed (#{response.code}): #{response.body}"
  end

  JSON.parse(response.body)
end
