class LibraryController < ApplicationController
  def show
    @artist_count = Artist.count
    @album_count = Album.count
    @track_count = Track.count
    @total_duration = Track.sum(:duration)
    @recent_tracks = Track.includes(:artist, :album).order(created_at: :desc).limit(10)
  end
end
