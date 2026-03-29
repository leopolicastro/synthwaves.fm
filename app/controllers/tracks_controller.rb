class TracksController < ApplicationController
  include Orderable
  include AdminAuthorization

  allow_unauthenticated_access only: [:lyrics]
  before_action :set_track, only: [:show, :edit, :update, :destroy, :stream, :download, :enrich]
  before_action :set_track_public, only: [:lyrics]
  before_action :require_admin, only: [:edit, :update, :destroy]

  def index
    @query = params[:q]
    @sort = sort_column(Track, default: "created_at")
    @direction = sort_direction
    scope = Current.user.tracks.music.includes(:artist, :album).search(@query)
    scope = scope.by_genre(params[:genre]) if params[:genre].present?
    scope = scope.by_language(params[:language]) if params[:language].present?
    scope = scope.by_decade(params[:decade]) if params[:decade].present?
    scope = scope.order(@sort => @direction)
    @pagy, @tracks = pagy(:offset, scope)
    @favorited_track_ids = Current.user.favorited_ids_for("Track")

    user_tracks = Current.user.tracks.music
    @genres = user_tracks.genre_names
    @languages = user_tracks.available_languages
    @decades = user_tracks.available_decades
  end

  def show
    @track_playlists = @track.playlists.where(user: Current.user).order(:name)
  end

  def new
    @track = Track.new
  end

  def create
    uploaded_file = params[:audio_file]

    if uploaded_file.blank?
      @track = Track.new
      @track.errors.add(:audio_file, "must be attached")
      render :new, status: :unprocessable_content
      return
    end

    file_format = uploaded_file.original_filename[/\.\w+$/]&.delete(".")
    metadata = extract_metadata(uploaded_file, file_format)

    artist = Current.user.artists.find_or_create_by!(name: metadata[:artist] || "Unknown Artist")
    album = Current.user.albums.find_or_create_by!(title: metadata[:album] || "Unknown Album", artist: artist) do |a|
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

    @track = Track.new(
      title: metadata[:title] || uploaded_file.original_filename.sub(/\.\w+$/, ""),
      user: Current.user,
      artist: artist,
      album: album,
      track_number: metadata[:track_number],
      disc_number: metadata[:disc_number] || 1,
      duration: metadata[:duration],
      bitrate: metadata[:bitrate],
      file_format: file_format,
      file_size: uploaded_file.size
    )

    @track.audio_file.attach(uploaded_file)

    if @track.save
      redirect_to @track, notice: "Track uploaded successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @artists = Current.user.artists.order(:name)
    @albums = Current.user.albums.includes(:artist).order(:title)
  end

  def update
    if @track.update(track_params)
      redirect_to @track, notice: "Track updated successfully."
    else
      @artists = Current.user.artists.order(:name)
      @albums = Current.user.albums.includes(:artist).order(:title)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @track.destroy
    redirect_to tracks_path, notice: "Track deleted."
  end

  def stream
    if @track.audio_file.attached?
      if params[:resolve].present? && cloud_storage?
        render json: {url: @track.audio_file.url(expires_in: 4.hours)}
      elsif params[:proxy].present? || !cloud_storage?
        redirect_to rails_storage_proxy_url(@track.audio_file)
      else
        redirect_to @track.audio_file.url(expires_in: 4.hours), allow_other_host: true
      end
    else
      head :not_found
    end
  end

  def download
    if !@track.audio_file.attached?
      redirect_to track_path(@track), alert: "This track is not available for download."
      return
    end

    redirect_to rails_blob_path(@track.audio_file, disposition: "attachment"), allow_other_host: true
  end

  def lyrics
    lyrics = LyricsService.new(@track).fetch
    render json: {lyrics: lyrics}
  end

  def enrich
    unless @track.youtube?
      redirect_to @track, alert: "Metadata enrichment is only available for YouTube tracks."
      return
    end

    enriched = YoutubeMetadataEnricher.call(title: @track.title, channel_name: @track.artist.name)

    if enriched[:source] == :parsed
      artist = Current.user.artists.find_or_create_by!(name: enriched[:artist])
      @track.update!(title: enriched[:title], artist: artist)
      redirect_to @track, notice: "Metadata enriched: artist set to \"#{enriched[:artist]}\" and title cleaned to \"#{enriched[:title]}\"."
    else
      redirect_to @track, notice: "No artist/title pattern found in the track title. No changes made."
    end
  end

  private

  def set_track
    @track = Current.user.tracks.find(params[:id])
  end

  def set_track_public
    @track = Track.find(params[:id])
  end

  def track_params
    params.require(:track).permit(:title, :track_number, :disc_number, :lyrics, :album_id, :artist_id, :language, :release_year, :content_rating)
  end

  def cloud_storage?
    !ActiveStorage::Blob.service.class.name.include?("Disk")
  end

  def extract_metadata(uploaded_file, file_format)
    MetadataExtractor.call(uploaded_file.tempfile.path)
  rescue WahWah::WahWahArgumentError
    {}
  end
end
