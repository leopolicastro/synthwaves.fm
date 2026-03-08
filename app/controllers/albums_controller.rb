class AlbumsController < ApplicationController
  def index
    @albums = Album.music.includes(:artist).order(:title)
  end

  def show
    @album = Album.includes(:artist, tracks: :artist).find(params[:id])
    @sort = sort_column(Track, default: "disc_number")
    @direction = sort_direction

    scope = if @sort == "disc_number"
      @album.tracks.order(disc_number: @direction, track_number: @direction)
    else
      @album.tracks.order(@sort => @direction)
    end

    @total_tracks = scope.count
    @all_tracks = @album.tracks
    @pagy, @tracks = pagy(:offset, scope)
    @favorited_track_ids = Current.user.favorites.where(favorable_type: "Track").pluck(:favorable_id).to_set
  end

  def refresh
    album = Album.find(params[:id])

    unless Flipper.enabled?(:youtube_import, Current.user)
      redirect_to album, alert: "This feature is not available."
      return
    end

    unless album.youtube_playlist_url.present?
      redirect_to album, alert: "This album has no YouTube playlist URL to refresh from."
      return
    end

    track_count_before = album.tracks.count
    YoutubePlaylistImportService.call(album.youtube_playlist_url, category: album.artist.category)
    new_count = album.tracks.reload.count - track_count_before

    if new_count > 0
      redirect_to album, notice: "#{new_count} new #{"episode".pluralize(new_count)} added."
    else
      redirect_to album, notice: "No new episodes found."
    end
  rescue YoutubePlaylistImportService::Error => e
    redirect_to album, alert: "Refresh failed: #{e.message}"
  end

  def update
    album = Album.find(params[:id])
    if album.update(album_params)
      redirect_to album, notice: "Album updated."
    else
      redirect_to album, alert: "Failed to update album."
    end
  end

  def fetch_cover
    album = Album.find(params[:id])

    result = CoverArtSearchService.call(album)

    if result == :not_found
      redirect_to album, alert: "No cover art found."
    else
      redirect_to album, notice: "Cover art updated from #{result} source."
    end
  end

  def create_playlist
    album = Album.find(params[:id])
    tracks = album.tracks.order(:disc_number, :track_number)
    playlist = Current.user.playlists.create!(name: album.title)

    tracks.each_with_index do |track, index|
      playlist.playlist_tracks.create!(track: track, position: index + 1)
    end

    redirect_to playlist, notice: "Playlist created from #{album.title}"
  end

  private

  def album_params
    params.require(:album).permit(:youtube_playlist_url)
  end
end
