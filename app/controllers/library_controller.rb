class LibraryController < ApplicationController
  def show
    @greeting = time_of_day_greeting
    @user_display_name = Current.user.name.presence || Current.user.email_address.split("@").first

    @recently_played_albums = recently_played_albums
    @playlists = Current.user.playlists
      .left_joins(:playlist_tracks)
      .select("playlists.*, COUNT(playlist_tracks.id) AS tracks_count")
      .group("playlists.id")
      .order(updated_at: :desc)
      .limit(10)

    @favorite_tracks = Current.user.favorites
      .where(favorable_type: "Track")
      .includes(favorable: [ :artist, :album ])
      .order(created_at: :desc)
      .limit(10)

    if Flipper.enabled?(:youtube_radio, Current.user)
      @radio_stations = Current.user.radio_stations.order(created_at: :desc).limit(10)
    end

    @recently_added_albums = Album.music
      .joins(:tracks)
      .includes(:artist)
      .select("albums.*, MAX(tracks.created_at) AS latest_track_at")
      .group("albums.id")
      .order("latest_track_at DESC")
      .limit(10)

    @podcasts = Artist.podcast.limit(10)

    @artist_count = Artist.music.count
    @album_count = Album.music.count
    @track_count = Track.music.count
    @podcast_count = Artist.podcast.count
  end

  private

  def time_of_day_greeting
    hour = Time.current.hour
    if hour < 12
      "Good morning"
    elsif hour < 18
      "Good afternoon"
    else
      "Good evening"
    end
  end

  def recently_played_albums
    Album.joins(tracks: :play_histories)
      .where(play_histories: { user_id: Current.user.id })
      .select("albums.*, MAX(play_histories.played_at) AS last_played_at")
      .group("albums.id")
      .order("last_played_at DESC")
      .includes(:artist)
      .limit(10)
  end
end
