class PlaylistTracksController < ApplicationController
  before_action :set_playlist

  def create
    if params[:track_ids].present?
      add_multiple_tracks
    elsif params[:album_id].present?
      add_album_tracks
    else
      add_single_track
    end

    redirect_back fallback_location: @playlist
  end

  def destroy
    @playlist.playlist_tracks.find(params[:id]).destroy
    redirect_back fallback_location: @playlist
  end

  private

  def add_multiple_tracks
    tracks = Current.user.tracks.where(id: params[:track_ids])
    ordered = params[:track_ids].map(&:to_i).filter_map { |id| tracks.find { |t| t.id == id } }
    @playlist.add_tracks(ordered)
  end

  def add_single_track
    track = Current.user.tracks.find(params[:track_id])
    @playlist.add_track(track)
  end

  def add_album_tracks
    album = Current.user.albums.find(params[:album_id])
    @playlist.add_tracks(album.tracks.order(:disc_number, :track_number))
  end

  def set_playlist
    @playlist = Current.user.playlists.find(params[:playlist_id])
  end
end
