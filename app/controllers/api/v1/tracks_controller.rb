class API::V1::TracksController < API::V1::BaseController
  before_action :set_track, only: [:show, :update, :destroy, :stream]

  def index
    scope = current_user.tracks.includes(:artist, :album)
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(album_id: params[:album_id]) if params[:album_id].present?
    scope = scope.where(artist_id: params[:artist_id]) if params[:artist_id].present?
    scope = scope.by_genre(params[:genre]) if params[:genre].present?
    scope = scope.by_language(params[:language]) if params[:language].present?
    scope = scope.by_decade(params[:decade]) if params[:decade].present?
    scope = scope.order(sort_column(Track) => sort_direction)

    pagy, tracks = pagy(:offset, scope, limit: per_page)

    render json: {
      tracks: tracks.map { |t| API::V1::TrackSerializer.to_full(t) },
      pagination: pagination_meta(pagy)
    }
  end

  def show
    render json: API::V1::TrackSerializer.to_full(@track)
  end

  def create
    if params[:audio_file].present?
      create_from_upload
    elsif params[:signed_blob_id].present?
      create_from_direct_upload
    elsif params[:track].present?
      create_from_params
    else
      render_error("audio_file, signed_blob_id, or track params required")
    end
  end

  def update
    if @track.update(track_update_params)
      render json: API::V1::TrackSerializer.to_full(@track)
    else
      render_validation_errors(@track)
    end
  end

  def destroy
    @track.destroy
    head :no_content
  end

  def stream
    unless @track.audio_file.attached?
      return render_error("No audio file attached", status: :not_found)
    end

    render json: {
      url: url_for(@track.audio_file),
      content_type: @track.audio_file.content_type,
      file_size: @track.audio_file.byte_size
    }
  end

  private

  def set_track
    @track = current_user.tracks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def create_from_upload
    uploaded_file = params[:audio_file]
    file_format = uploaded_file.original_filename[/\.\w+$/]&.delete(".")
    metadata = extract_metadata(uploaded_file)

    artist, album = ArtistAlbumResolver.call(
      user: current_user,
      artist_name: metadata[:artist],
      album_title: metadata[:album],
      year: metadata[:year],
      genre: metadata[:genre]
    )

    track = Track.new(
      title: metadata[:title] || uploaded_file.original_filename.sub(/\.\w+$/, ""),
      user: current_user,
      artist: artist,
      album: album,
      track_number: metadata[:track_number],
      disc_number: metadata[:disc_number] || 1,
      duration: metadata[:duration],
      bitrate: metadata[:bitrate],
      file_format: file_format,
      file_size: uploaded_file.size
    )

    begin
      track.audio_file.attach(uploaded_file)
    rescue => e
      return render_error("Upload failed: #{e.message}", status: :service_unavailable)
    end

    if track.save
      render json: API::V1::TrackSerializer.to_full(track), status: :created
    else
      render_validation_errors(track)
    end
  end

  def create_from_direct_upload
    blob = ActiveStorage::Blob.find_signed!(params[:signed_blob_id])

    artist, album = ArtistAlbumResolver.call(
      user: current_user,
      artist_name: params[:artist_name],
      album_title: params[:album_title],
      year: params[:year]&.to_i,
      genre: params[:genre]
    )

    track = Track.new(
      title: params[:title] || blob.filename.to_s.sub(/\.\w+$/, ""),
      user: current_user,
      artist: artist,
      album: album,
      track_number: params[:track_number]&.to_i,
      disc_number: params[:disc_number]&.to_i || 1,
      duration: params[:duration]&.to_f,
      bitrate: params[:bitrate]&.to_i,
      file_format: params[:file_format],
      file_size: blob.byte_size
    )

    begin
      track.audio_file.attach(blob)
    rescue => e
      return render_error("Upload failed: #{e.message}", status: :service_unavailable)
    end

    if track.save
      render json: API::V1::TrackSerializer.to_full(track), status: :created
    else
      render_validation_errors(track)
    end
  end

  def create_from_params
    track = current_user.tracks.build(track_create_params)

    if track.save
      render json: API::V1::TrackSerializer.to_full(track), status: :created
    else
      render_validation_errors(track)
    end
  end

  def track_create_params
    params.require(:track).permit(
      :title, :artist_id, :album_id, :track_number, :disc_number,
      :duration, :bitrate, :file_format, :file_size, :lyrics
    )
  end

  def track_update_params
    params.require(:track).permit(
      :title, :artist_id, :album_id, :track_number, :disc_number,
      :lyrics, :language, :release_year, :content_rating
    )
  end

  def extract_metadata(uploaded_file)
    MetadataExtractor.call(uploaded_file.tempfile.path)
  rescue WahWah::WahWahArgumentError
    {}
  end
end
