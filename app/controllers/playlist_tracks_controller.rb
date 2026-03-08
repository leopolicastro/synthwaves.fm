class PlaylistTracksController < ApplicationController
  before_action :set_playlist

  def create
    track = Track.find(params[:track_id])

    unless @playlist.playlist_tracks.exists?(track: track)
      next_position = (@playlist.playlist_tracks.maximum(:position) || 0) + 1
      @playlist.playlist_tracks.create!(track: track, position: next_position)
    end

    redirect_back fallback_location: @playlist
  end

  def destroy
    @playlist.playlist_tracks.find(params[:id]).destroy
    redirect_back fallback_location: @playlist
  end

  private

  def set_playlist
    @playlist = Current.user.playlists.find(params[:playlist_id])
  end
end
