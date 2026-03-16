require "aws-sdk-s3"

class S3RecoveryService
  AUDIO_TYPES = %w[audio/mpeg audio/mp3 audio/flac audio/x-flac audio/ogg audio/wav audio/x-wav audio/aac audio/mp4 audio/x-m4a].freeze
  VIDEO_TYPES = %w[video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg].freeze
  IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  def self.call(user_email:, commit: false)
    new(user_email: user_email, commit: commit).call
  end

  def initialize(user_email:, commit: false)
    @user_email = user_email
    @commit = commit
    @stats = {scanned: 0, audio_created: 0, video_created: 0, existing: 0, skipped: 0, errors: 0}
  end

  def call
    @user = User.find_by!(email_address: @user_email)

    orphaned = scan_and_categorize
    recover_audio_files(orphaned[:audio])
    recover_video_files(orphaned[:video])
    log_images(orphaned[:image])

    log "Recovery complete: #{@stats.inspect}"
    @stats
  end

  private

  def scan_and_categorize
    categorized = {audio: [], video: [], image: [], unknown: []}
    continuation_token = nil

    loop do
      params = {bucket: bucket, prefix: ""}
      params[:continuation_token] = continuation_token if continuation_token

      response = s3_client.list_objects_v2(**params)

      response.contents.each do |object|
        @stats[:scanned] += 1
        next if object.key.start_with?("backups/")

        if ActiveStorage::Blob.exists?(key: object.key)
          @stats[:existing] += 1
          next
        end

        head = s3_client.head_object(bucket: bucket, key: object.key)
        content_type = head.content_type
        filename = parse_filename(head.content_disposition, object.key)

        entry = {
          key: object.key,
          content_type: content_type,
          filename: filename,
          size: object.size,
          etag: head.etag&.delete('"')
        }

        category = categorize(content_type)
        categorized[category] << entry
      end

      break unless response.is_truncated
      continuation_token = response.next_continuation_token
    end

    log "Scanned #{@stats[:scanned]} objects: #{categorized[:audio].size} audio, #{categorized[:video].size} video, #{categorized[:image].size} image"
    categorized
  end

  def recover_audio_files(entries)
    entries.each do |entry|
      recover_audio(entry)
    rescue => e
      @stats[:errors] += 1
      log "ERROR recovering audio #{entry[:key]}: #{e.message}"
    end
  end

  def recover_audio(entry)
    Dir.mktmpdir("s3_recovery") do |tmpdir|
      tmp_path = File.join(tmpdir, entry[:filename])
      download_to(entry[:key], tmp_path)

      metadata = MetadataExtractor.call(tmp_path)
      checksum = compute_md5(tmp_path)

      artist_name = metadata[:artist].presence || "Unknown Artist"
      album_title = metadata[:album].presence || "Unknown Album"
      title = metadata[:title].presence || File.basename(entry[:filename], File.extname(entry[:filename]))

      if @commit
        artist = @user.artists.find_or_create_by!(name: artist_name)
        album = @user.albums.find_or_create_by!(title: album_title, artist: artist) do |a|
          a.genre = metadata[:genre]
          a.year = metadata[:year]
        end

        if @user.tracks.exists?(title: title, album: album, artist: artist)
          @stats[:skipped] += 1
          log "SKIP (duplicate): #{artist_name} - #{title}"
          return
        end

        track = Track.new(
          title: title,
          user: @user,
          album: album,
          artist: artist,
          track_number: metadata[:track_number],
          disc_number: metadata[:disc_number],
          duration: metadata[:duration],
          bitrate: metadata[:bitrate],
          file_format: File.extname(entry[:filename]).delete("."),
          file_size: entry[:size]
        )
        track.define_singleton_method(:convert_audio_if_needed) {}
        track.save!

        blob = ActiveStorage::Blob.create!(
          key: entry[:key],
          filename: entry[:filename],
          content_type: entry[:content_type],
          byte_size: entry[:size],
          checksum: checksum,
          service_name: storage_service_name
        )
        ActiveStorage::Attachment.create!(name: "audio_file", record: track, blob: blob)

        attach_cover_art(album, metadata[:cover_art]) if metadata[:cover_art] && !album.cover_image.attached?

        @stats[:audio_created] += 1
        log "CREATED track: #{artist_name} - #{title} (#{album_title})"
      else
        log "DRY-RUN would create: #{artist_name} - #{title} (#{album_title})"
        @stats[:audio_created] += 1
      end
    end
  end

  def recover_video_files(entries)
    entries.each do |entry|
      recover_video(entry)
    rescue => e
      @stats[:errors] += 1
      log "ERROR recovering video #{entry[:key]}: #{e.message}"
    end
  end

  def recover_video(entry)
    parsed = FilenameEpisodeParser.parse(entry[:filename])
    title = parsed.title.presence || File.basename(entry[:filename], File.extname(entry[:filename]))
    checksum = base64_etag(entry[:etag])

    if @commit
      video = Video.new(
        title: title,
        user: @user,
        season_number: parsed.season_number,
        episode_number: parsed.episode_number,
        status: "ready",
        file_format: File.extname(entry[:filename]).delete("."),
        file_size: entry[:size]
      )
      video.define_singleton_method(:convert_video) {}
      video.save!

      blob = ActiveStorage::Blob.create!(
        key: entry[:key],
        filename: entry[:filename],
        content_type: entry[:content_type],
        byte_size: entry[:size],
        checksum: checksum,
        service_name: storage_service_name
      )
      ActiveStorage::Attachment.create!(name: "file", record: video, blob: blob)

      @stats[:video_created] += 1
      log "CREATED video: #{title} (S#{parsed.season_number}E#{parsed.episode_number})"
    else
      log "DRY-RUN would create video: #{title} (S#{parsed.season_number}E#{parsed.episode_number})"
      @stats[:video_created] += 1
    end
  end

  def log_images(entries)
    entries.each do |entry|
      log "IMAGE for manual review: #{entry[:key]} (#{entry[:filename]})"
      @stats[:skipped] += 1
    end
  end

  def attach_cover_art(album, cover_art)
    ext = case cover_art[:mime_type]
    when "image/png" then ".png"
    when "image/gif" then ".gif"
    else ".jpg"
    end

    album.cover_image.attach(
      io: StringIO.new(cover_art[:data]),
      filename: "cover#{ext}",
      content_type: cover_art[:mime_type]
    )
  end

  def parse_filename(content_disposition, key)
    if content_disposition.present?
      # Handle quoted: filename="my song.mp3"
      if (match = content_disposition.match(/filename\*?=(?:UTF-8'')?["']([^"']+)["']/i))
        decoded = CGI.unescape(match[1])
        return decoded if decoded.present?
      end
      # Handle unquoted: filename=song.mp3
      if (match = content_disposition.match(/filename\*?=(?:UTF-8'')?([^"';\s]+)/i))
        decoded = CGI.unescape(match[1])
        return decoded if decoded.present?
      end
    end

    # Fall back to the S3 key's basename
    File.basename(key)
  end

  def categorize(content_type)
    return :audio if AUDIO_TYPES.include?(content_type)
    return :video if VIDEO_TYPES.include?(content_type)
    return :image if IMAGE_TYPES.include?(content_type)
    :unknown
  end

  def download_to(key, path)
    s3_client.get_object(
      response_target: path,
      bucket: bucket,
      key: key
    )
  end

  def compute_md5(file_path)
    Base64.strict_encode64(Digest::MD5.file(file_path).digest)
  end

  def base64_etag(etag)
    return nil unless etag
    # Multipart ETags contain a dash — not a real MD5, use as-is in base64
    if etag.include?("-")
      Base64.strict_encode64(etag)
    else
      Base64.strict_encode64([etag].pack("H*"))
    end
  end

  def log(message)
    Rails.logger.info("[S3Recovery] #{message}")
    puts "[S3Recovery] #{message}" unless Rails.env.test?
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: credentials[:access_key_id],
      secret_access_key: credentials[:secret_access_key],
      region: credentials[:region],
      endpoint: credentials[:endpoint]
    )
  end

  def bucket
    credentials[:bucket]
  end

  def storage_service_name
    Rails.configuration.active_storage.service.to_s
  end

  def credentials
    @credentials ||= Rails.application.credentials.linode
  end
end
