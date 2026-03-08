class PlaylistsController < ApplicationController
  before_action :set_playlist, only: [:show, :edit, :update, :destroy]

  def index
    @playlists = Current.user.playlists.order(:name)
  end

  def show
    @playlist_tracks = @playlist.playlist_tracks.includes(track: [:artist, :album])
    @favorited_track_ids = Current.user.favorites.where(favorable_type: "Track").pluck(:favorable_id).to_set
  end

  def new
    @playlist = Playlist.new
  end

  def create
    @playlist = Current.user.playlists.build(playlist_params)
    if @playlist.save
      add_tracks_if_present
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

  def add_tracks_if_present
    return unless params[:track_ids].present?

    tracks = Track.where(id: params[:track_ids])
    track_ids_ordered = params[:track_ids].map(&:to_i)
    position = 1

    track_ids_ordered.each do |track_id|
      track = tracks.find { |t| t.id == track_id }
      next unless track
      @playlist.playlist_tracks.create!(track: track, position: position)
      position += 1
    end
  end

  def playlist_params
    params.require(:playlist).permit(:name)
  end
end
