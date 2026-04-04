class API::V1::AlbumsController < API::V1::BaseController
  before_action :set_album, only: [:show, :update, :destroy]

  def index
    scope = current_user.albums.includes(:artist, cover_image_attachment: :blob)
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(artist_id: params[:artist_id]) if params[:artist_id].present?
    scope = scope.order(sort_column(Album) => sort_direction)

    pagy, albums = pagy(:offset, scope, limit: per_page)

    render json: {
      albums: albums.map { |a| album_json(a) },
      pagination: pagination_meta(pagy)
    }
  end

  def show
    tracks = @album.tracks.order(disc_number: :asc, track_number: :asc)

    render json: album_json(@album).merge(
      total_duration: tracks.sum(:duration),
      tracks: tracks.map { |t| track_summary_json(t) }
    )
  end

  def create
    album = current_user.albums.build(album_params)

    if album.save
      attach_cover_image(album)
      render json: album_json(album), status: :created
    else
      render_validation_errors(album)
    end
  end

  def update
    if @album.update(album_params)
      attach_cover_image(@album)
      render json: album_json(@album)
    else
      render_validation_errors(@album)
    end
  end

  def destroy
    @album.destroy
    head :no_content
  end

  private

  def set_album
    @album = current_user.albums.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def album_params
    params.require(:album).permit(:title, :artist_id, :year, :genre)
  end

  def attach_cover_image(album)
    if params[:cover_image].present?
      album.cover_image.attach(params[:cover_image])
    elsif params[:cover_image_signed_id].present?
      album.cover_image.attach(params[:cover_image_signed_id])
    end
  end

  def album_json(album)
    {
      id: album.id,
      title: album.title,
      year: album.year,
      genre: album.genre,
      artist: {id: album.artist_id, name: album.artist.name},
      tracks_count: album.tracks.size,
      cover_image_url: album.cover_image.attached? ? url_for(album.cover_image) : nil,
      created_at: album.created_at
    }
  end

  def track_summary_json(track)
    {
      id: track.id,
      title: track.title,
      track_number: track.track_number,
      disc_number: track.disc_number,
      duration: track.duration,
      file_format: track.file_format,
      has_audio: track.audio_file.attached?
    }
  end
end
