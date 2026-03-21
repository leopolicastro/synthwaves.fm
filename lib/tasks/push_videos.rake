require_relative "remote_api"

namespace :videos do
  desc "Encode (if needed) and push a video to a remote synthwaves.fm instance via S3 direct upload"
  task push: :environment do
    require "digest"
    require "base64"
    require "open3"

    synthwaves = Rails.application.credentials.synthwaves
    abort "synthwaves credentials not configured" unless synthwaves

    remote_url = synthwaves[:url] || abort("synthwaves.url is required in credentials")
    client_id = synthwaves[:client_id] || abort("synthwaves.client_id is required in credentials")
    secret_key = synthwaves[:secret_key] || abort("synthwaves.secret_key is required in credentials")
    video_path = File.expand_path(ENV.fetch("VIDEO_PATH", "~/Movies"))
    exclude_path = File.expand_path(ENV.fetch("EXCLUDE_PATH", "~/Movies/Transmissions"))
    abort "Not found: #{video_path}" unless File.exist?(video_path)

    video_extensions = %w[mp4 mkv avi mov m4v wmv flv webm ts]
    pattern = File.join(video_path, "**", "*.{#{video_extensions.join(",")}}")
    video_files = Dir.glob(pattern).sort
    video_files.reject! { |f| f.start_with?(exclude_path) }

    if video_files.empty?
      puts "No video files found in #{video_path}"
      exit
    end

    puts "Found #{video_files.size} video files in #{video_path}"

    # Authenticate and re-authenticate before token expires
    puts "Authenticating..."
    token = RemoteAPI.authenticate(remote_url, client_id, secret_key)
    token_issued_at = Time.now

    uploaded = 0
    failed = 0

    video_files.each_with_index do |video_file, index|
      temp_file = nil
      label = (video_files.size > 1) ? "[#{index + 1}/#{video_files.size}] " : ""

      begin
        # Re-authenticate if token is older than 50 minutes
        if Time.now - token_issued_at > 3000
          puts "  Refreshing token..."
          token = RemoteAPI.authenticate(remote_url, client_id, secret_key)
          token_issued_at = Time.now
        end

        title = File.basename(video_file, File.extname(video_file))
        folder_name = ENV["FOLDER"] || begin
          rel = Pathname.new(video_file).relative_path_from(Pathname.new(video_path)).to_s
          parts = rel.split("/")
          (parts.length > 1) ? parts.first : nil
        end

        # 1. Probe input
        puts "#{label}Probing #{File.basename(video_file)}..."
        probe = probe_video(video_file)
        strategy = encoding_strategy(probe, video_file)
        puts "  Video: #{probe[:video_codec]}, Audio: #{probe[:audio_codec]}, Container: #{probe[:container]}"
        puts "  Strategy: #{strategy}"

        # 2. Encode if needed
        upload_path = video_file

        case strategy
        when :remux
          temp_file = "#{video_file}.remuxed.mp4"
          puts "  Remuxing to MP4 with faststart..."
          remux(video_file, temp_file)
          upload_path = temp_file
        when :full
          temp_file = "#{video_file}.encoded.mp4"
          puts "  Encoding with h264_videotoolbox..."
          encode(video_file, temp_file)
          upload_path = temp_file
        else
          puts "  Already H264+AAC+MP4 — uploading original"
        end

        # 3. Create blob via API
        file_size = File.size(upload_path)
        checksum = Digest::MD5.file(upload_path).base64digest
        filename = "#{File.basename(video_file, File.extname(video_file))}.mp4"

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
        video = create_video_record(remote_url, token, signed_id, title, folder_name)
        puts "  Created: \"#{video["title"]}\" (id: #{video["id"]}, status: #{video["status"]})"

        # 6. Delete local file
        File.delete(video_file)
        puts "  Deleted local file"

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

    # Remove empty directories left behind after file deletions
    dirs = video_files.map { |f| File.dirname(f) }.uniq.sort_by { |d| -d.length }
    dirs.each do |dir|
      while dir != video_path && Dir.exist?(dir) && (Dir.entries(dir) - %w[. ..]).empty?
        Dir.rmdir(dir)
        puts "Removed empty directory: #{dir}"
        dir = File.dirname(dir)
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
    "-ac", "2", "-c:a", "aac", "-b:a", "128k",
    "-movflags", "+faststart",
    "-tag:v", "avc1",
    output
  )
  abort "ffmpeg encode failed" unless success
end

def create_video_record(remote_url, token, signed_blob_id, title, folder_name)
  uri = URI.parse("#{remote_url}/api/import/videos")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 15
  http.read_timeout = 30

  body = {signed_blob_id: signed_blob_id, title: title}
  body[:folder_name] = folder_name if folder_name

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
