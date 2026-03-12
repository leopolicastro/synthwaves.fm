class ArtistsController < ApplicationController
  include Orderable
  include AdminAuthorization

  before_action :require_admin, only: [:edit, :update, :destroy]

  def index
    @query = params[:q]
    @sort = sort_column(Artist, default: "name")
    @direction = sort_direction
    scope = Artist.music.includes(albums: { cover_image_attachment: :blob })
              .search(@query)
              .order(@sort => @direction)
    @pagy, @artists = pagy(:offset, scope)
  end

  def show
    @artist = Artist.find(params[:id])
    @albums = @artist.albums.includes(:tracks).order(:year)
  end

  def edit
    @artist = Artist.find(params[:id])
  end

  def update
    @artist = Artist.find(params[:id])
    if @artist.update(artist_params)
      redirect_to @artist, notice: "Artist updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @artist = Artist.find(params[:id])
    @artist.destroy
    redirect_to artists_path, notice: "Artist deleted."
  end

  private

  def artist_params
    params.require(:artist).permit(:name, :category)
  end
end
