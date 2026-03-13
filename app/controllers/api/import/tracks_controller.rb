class API::Import::TracksController < API::Import::BaseController
  def create
    if params[:signed_blob_id].present?
      create_from_direct_upload
    elsif params[:audio_file].present?
      create_from_multipart
    else
      render json: { error: "audio_file or signed_blob_id is required" }, status: :unprocessable_entity
    end
  end

  private

  def create_from_multipart
    uploaded_file = params[:audio_file]
    file_format = uploaded_file.original_filename[/\.\w+$/]&.delete(".")
    metadata = extract_metadata(uploaded_file)

    create_track(
      metadata: metadata,
      file_format: file_format,
      file_size: uploaded_file.size,
      fallback_title: uploaded_file.original_filename.sub(/\.\w+$/, "")
    ) { |track| track.audio_file.attach(uploaded_file) }
  end

  def create_from_direct_upload
    blob = ActiveStorage::Blob.find_signed!(params[:signed_blob_id])

    metadata = {
      title: params[:title],
      artist: params[:artist],
      album: params[:album],
      year: params[:year]&.to_i,
      genre: params[:genre],
      track_number: params[:track_number]&.to_i,
      disc_number: params[:disc_number]&.to_i,
      duration: params[:duration]&.to_f,
      bitrate: params[:bitrate]&.to_i,
      cover_art: nil
    }

    if params[:cover_art].present? && params[:cover_art_mime_type].present?
      metadata[:cover_art] = { data: Base64.decode64(params[:cover_art]), mime_type: params[:cover_art_mime_type] }
    end

    create_track(
      metadata: metadata,
      file_format: params[:file_format],
      file_size: blob.byte_size,
      fallback_title: blob.filename.to_s.sub(/\.\w+$/, "")
    ) { |track| track.audio_file.attach(blob) }
  end

  def create_track(metadata:, file_format:, file_size:, fallback_title:)
    artist = current_user.artists.find_or_create_by!(name: metadata[:artist] || "Unknown Artist")
    album = current_user.albums.find_or_create_by!(title: metadata[:album] || "Unknown Album", artist: artist) do |a|
      a.year = metadata[:year]
      a.genre = metadata[:genre]
    end

    if metadata[:cover_art] && !album.cover_image.attached?
      CoverArtAttachJob.perform_later(album, Base64.strict_encode64(metadata[:cover_art][:data]), metadata[:cover_art][:mime_type])
    end

    title = metadata[:title] || fallback_title
    track_number = metadata[:track_number]

    existing = current_user.tracks.find_by(title: title, album: album, artist: artist, track_number: track_number)

    if existing&.audio_file&.attached?
      render json: {
        id: existing.id,
        title: existing.title,
        artist: artist.name,
        album: album.title,
        created: false
      }
      return
    end

    existing&.destroy

    track = Track.new(
      title: title,
      user: current_user,
      artist: artist,
      album: album,
      track_number: track_number,
      disc_number: metadata[:disc_number] || 1,
      duration: metadata[:duration],
      bitrate: metadata[:bitrate],
      file_format: file_format,
      file_size: file_size
    )

    begin
      yield track
    rescue => e
      render json: { error: "Upload failed: #{e.message}" }, status: :service_unavailable
      return
    end

    if track.save
      render json: {
        id: track.id,
        title: track.title,
        artist: artist.name,
        album: album.title,
        created: true
      }, status: :created
    else
      render json: { error: track.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def extract_metadata(uploaded_file)
    MetadataExtractor.call(uploaded_file.tempfile.path)
  rescue WahWah::WahWahArgumentError
    {}
  end
end
