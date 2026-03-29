class MusicController < ApplicationController
  include Orderable

  def show
    @available_tabs = available_tabs
    @tab = params[:tab].presence_in(@available_tabs) || "artists"

    case @tab
    when "artists"
      load_artists
    when "albums"
      load_albums
    when "tracks"
      load_tracks
    when "playlists"
      load_playlists
    when "radio"
      load_radio
    when "internet_radio"
      load_internet_radio
    end
  end

  private

  def available_tabs
    tabs = %w[artists albums tracks playlists]
    tabs << "radio" if Flipper.enabled?(:youtube_radio, Current.user)
    tabs << "internet_radio" if Flipper.enabled?(:internet_radio, Current.user)
    tabs
  end

  def load_artists
    @query = params[:q]
    @sort = sort_column(Artist, default: "created_at")
    @direction = sort_direction
    scope = Current.user.artists.music.includes(albums: {cover_image_attachment: :blob})
      .search(@query)
      .order(@sort => @direction)
    @pagy, @artists = pagy(:offset, scope, limit: 24)
  end

  def load_albums
    @query = params[:q]
    @sort = sort_column(Album, default: "created_at")
    @direction = sort_direction
    scope = Current.user.albums.music.includes(:artist, cover_image_attachment: :blob)
      .search(@query)
      .order(@sort => @direction)
    @pagy, @albums = pagy(:offset, scope, limit: 24)
  end

  def load_tracks
    @query = params[:q]
    @sort = sort_column(Track, default: "created_at")
    @direction = sort_direction
    scope = Current.user.tracks.music.includes(:artist, :album).search(@query)
    scope = scope.by_genre(params[:genre]) if params[:genre].present?
    scope = scope.by_language(params[:language]) if params[:language].present?
    scope = scope.by_decade(params[:decade]) if params[:decade].present?
    scope = scope.order(@sort => @direction)
    @pagy, @tracks = pagy(:offset, scope, limit: 24)
    @favorited_track_ids = Current.user.favorited_ids_for("Track")

    user_tracks = Current.user.tracks.music
    @genres = user_tracks.genre_names
    @languages = user_tracks.available_languages
    @decades = user_tracks.available_decades
  end

  def load_playlists
    @query = params[:q]
    @sort = sort_column(Playlist, default: "created_at")
    @direction = sort_direction
    scope = Current.user.playlists.search(@query).order(@sort => @direction)
    @pagy, @playlists = pagy(:offset, scope, limit: 24)
    @cover_albums_by_playlist = Playlist.preload_cover_albums(@playlists)
  end

  def load_radio
    @external_streams = Current.user.external_streams.order(created_at: :desc)
  end

  def load_internet_radio
    @categories = InternetRadioCategory.with_stations.order(:name)
    scope = InternetRadioStation.active.includes(:internet_radio_category)

    if params[:category].present?
      @current_category = InternetRadioCategory.find_by(slug: params[:category])
      scope = scope.where(internet_radio_category: @current_category) if @current_category
    end

    if params[:favorites] == "1"
      favorite_ids = Current.user.favorited_ids_for("InternetRadioStation")
      scope = scope.where(id: favorite_ids)
    end

    scope = scope.search(params[:q])
    scope = scope.by_country(params[:country])
    scope = scope.by_tag(params[:tag])

    scope = case params[:sort]
    when "popular" then scope.popular
    else scope.order(:name)
    end

    @pagy, @stations = pagy(scope, limit: 24)

    @favorited_station_ids = Current.user.favorited_ids_for("InternetRadioStation")

    @countries = InternetRadioStation.active.where.not(country_code: [nil, ""]).distinct.pluck(:country_code).sort
  end
end
