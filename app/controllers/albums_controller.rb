class AlbumsController < ApplicationController
  def index
    @albums = Album.includes(:artist).order(:title)
  end

  def show
    @album = Album.includes(:artist, tracks: :artist).find(params[:id])
    @tracks = @album.tracks.order(:disc_number, :track_number)
  end
end
