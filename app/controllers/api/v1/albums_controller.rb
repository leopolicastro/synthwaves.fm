class API::V1::AlbumsController < API::V1::BaseController
  before_action :set_album, only: [:show, :update, :destroy]

  def index
    scope = current_user.albums.includes(:artist, cover_image_attachment: :blob)
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(artist_id: params[:artist_id]) if params[:artist_id].present?
    scope = scope.order(sort_column(Album) => sort_direction)

    pagy, albums = pagy(:offset, scope, limit: per_page)

    render json: {
      albums: API::V1::AlbumSerializer.render_as_hash(albums, view: :full),
      pagination: pagination_meta(pagy)
    }
  end

  def show
    tracks = @album.tracks.order(disc_number: :asc, track_number: :asc)

    render json: API::V1::AlbumSerializer.render_as_hash(@album, view: :full).merge(
      total_duration: tracks.sum(:duration),
      tracks: API::V1::TrackSerializer.render_as_hash(tracks, view: :summary)
    )
  end

  def create
    album = current_user.albums.build(album_params)

    if album.save
      attach_cover_image(album)
      render json: API::V1::AlbumSerializer.render_as_hash(album, view: :full), status: :created
    else
      render_validation_errors(album)
    end
  end

  def update
    if @album.update(album_params)
      attach_cover_image(@album)
      render json: API::V1::AlbumSerializer.render_as_hash(@album, view: :full)
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
end
