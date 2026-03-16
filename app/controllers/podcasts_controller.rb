class PodcastsController < ApplicationController
  def index
    @artists = Artist.podcast.includes(albums: {cover_image_attachment: :blob}).order(:name)
  end

  def show
    @artist = Artist.podcast.find(params[:id])
    @albums = @artist.albums.includes(:tracks).order(:year)
  end
end
