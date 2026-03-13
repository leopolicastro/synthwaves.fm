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
    track_ids_ordered = params[:track_ids].map(&:to_i)
    next_position = (@playlist.playlist_tracks.maximum(:position) || 0) + 1

    track_ids_ordered.each do |track_id|
      track = tracks.find { |t| t.id == track_id }
      next unless track
      unless @playlist.playlist_tracks.exists?(track: track)
        @playlist.playlist_tracks.create!(track: track, position: next_position)
        next_position += 1
      end
    end
  end

  def add_single_track
    track = Current.user.tracks.find(params[:track_id])

    unless @playlist.playlist_tracks.exists?(track: track)
      next_position = (@playlist.playlist_tracks.maximum(:position) || 0) + 1
      @playlist.playlist_tracks.create!(track: track, position: next_position)
    end
  end

  def add_album_tracks
    album = Current.user.albums.find(params[:album_id])
    tracks = album.tracks.order(:disc_number, :track_number)
    next_position = (@playlist.playlist_tracks.maximum(:position) || 0) + 1

    tracks.each do |track|
      unless @playlist.playlist_tracks.exists?(track: track)
        @playlist.playlist_tracks.create!(track: track, position: next_position)
        next_position += 1
      end
    end
  end

  def set_playlist
    @playlist = Current.user.playlists.find(params[:playlist_id])
  end
end
