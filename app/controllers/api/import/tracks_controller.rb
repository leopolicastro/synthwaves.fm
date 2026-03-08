class API::Import::TracksController < API::Import::BaseController
  def create
    uploaded_file = params[:audio_file]

    if uploaded_file.blank?
      render json: { error: "audio_file is required" }, status: :unprocessable_entity
      return
    end

    file_format = uploaded_file.original_filename[/\.\w+$/]&.delete(".")
    metadata = extract_metadata(uploaded_file)

    artist = Artist.find_or_create_by!(name: metadata[:artist] || "Unknown Artist")
    album = Album.find_or_create_by!(title: metadata[:album] || "Unknown Album", artist: artist) do |a|
      a.year = metadata[:year]
      a.genre = metadata[:genre]
    end

    if metadata[:cover_art] && !album.cover_image.attached?
      album.cover_image.attach(
        io: StringIO.new(metadata[:cover_art][:data]),
        filename: "cover.jpg",
        content_type: metadata[:cover_art][:mime_type] || "image/jpeg"
      )
    end

    title = metadata[:title] || uploaded_file.original_filename.sub(/\.\w+$/, "")
    track_number = metadata[:track_number]

    existing = Track.find_by(
      title: title,
      album: album,
      artist: artist,
      track_number: track_number
    )

    if existing
      render json: {
        id: existing.id,
        title: existing.title,
        artist: artist.name,
        album: album.title,
        created: false
      }
      return
    end

    track = Track.new(
      title: title,
      artist: artist,
      album: album,
      track_number: track_number,
      disc_number: metadata[:disc_number] || 1,
      duration: metadata[:duration],
      bitrate: metadata[:bitrate],
      file_format: file_format,
      file_size: uploaded_file.size
    )

    track.audio_file.attach(uploaded_file)

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

  private

  def extract_metadata(uploaded_file)
    MetadataExtractor.call(uploaded_file.tempfile.path)
  rescue WahWah::WahWahArgumentError
    {}
  end
end
