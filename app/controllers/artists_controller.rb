class ArtistsController < ApplicationController
  include Orderable

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
end
