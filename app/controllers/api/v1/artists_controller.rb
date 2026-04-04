class API::V1::ArtistsController < API::V1::BaseController
  before_action :set_artist, only: [:show, :update, :destroy]

  def index
    scope = current_user.artists
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.order(sort_column(Artist) => sort_direction)

    pagy, artists = pagy(:offset, scope, limit: per_page)

    render json: {
      artists: API::V1::ArtistSerializer.render_as_hash(artists, view: :full),
      pagination: pagination_meta(pagy)
    }
  end

  def show
    albums = @artist.albums.includes(cover_image_attachment: :blob).order(year: :desc, title: :asc)

    render json: API::V1::ArtistSerializer.render_as_hash(@artist, view: :full).merge(
      albums: API::V1::AlbumSerializer.render_as_hash(albums, view: :summary)
    )
  end

  def create
    artist = current_user.artists.build(artist_params)

    if artist.save
      render json: API::V1::ArtistSerializer.render_as_hash(artist, view: :full), status: :created
    else
      render_validation_errors(artist)
    end
  end

  def update
    if @artist.update(artist_params)
      render json: API::V1::ArtistSerializer.render_as_hash(@artist, view: :full)
    else
      render_validation_errors(@artist)
    end
  end

  def destroy
    @artist.destroy
    head :no_content
  end

  private

  def set_artist
    @artist = current_user.artists.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def artist_params
    params.require(:artist).permit(:name, :category)
  end
end
