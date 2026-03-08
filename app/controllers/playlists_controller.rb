class PlaylistsController < ApplicationController
  before_action :set_playlist, only: [:show, :edit, :update, :destroy]

  def index
    @playlists = Current.user.playlists.order(:name)
  end

  def show
    @playlist_tracks = @playlist.playlist_tracks.includes(track: [:artist, :album])
  end

  def new
    @playlist = Playlist.new
  end

  def create
    @playlist = Current.user.playlists.build(playlist_params)
    if @playlist.save
      redirect_to @playlist, notice: "Playlist created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to @playlist, notice: "Playlist updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @playlist.destroy
    redirect_to playlists_path, notice: "Playlist deleted."
  end

  private

  def set_playlist
    @playlist = Current.user.playlists.find(params[:id])
  end

  def playlist_params
    params.require(:playlist).permit(:name)
  end
end
