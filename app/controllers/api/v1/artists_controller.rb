class API::V1::ArtistsController < API::V1::BaseController
  before_action :set_artist, only: [:show, :update, :destroy]

  def index
    scope = current_user.artists
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.order(sort_column(Artist) => sort_direction)

    pagy, artists = pagy(:offset, scope, limit: per_page)

    render json: {
      artists: artists.map { |a| artist_json(a) },
      pagination: pagination_meta(pagy)
    }
  end

  def show
    albums = @artist.albums.includes(cover_image_attachment: :blob).order(year: :desc, title: :asc)

    render json: artist_json(@artist).merge(
      albums: albums.map { |a| album_summary_json(a) }
    )
  end

  def create
    artist = current_user.artists.build(artist_params)

    if artist.save
      render json: artist_json(artist), status: :created
    else
      render_validation_errors(artist)
    end
  end

  def update
    if @artist.update(artist_params)
      render json: artist_json(@artist)
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

  def artist_json(artist)
    {
      id: artist.id,
      name: artist.name,
      category: artist.category,
      image_url: artist.image_url,
      albums_count: artist.albums.size,
      tracks_count: artist.tracks.size,
      created_at: artist.created_at
    }
  end

  def album_summary_json(album)
    {
      id: album.id,
      title: album.title,
      year: album.year,
      genre: album.genre,
      tracks_count: album.tracks.size,
      cover_image_url: album.cover_image.attached? ? url_for(album.cover_image) : nil
    }
  end
end
