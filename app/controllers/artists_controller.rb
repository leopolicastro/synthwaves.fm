class ArtistsController < ApplicationController
  include Orderable
  include AdminAuthorization

  before_action :require_admin, only: [:edit, :update, :destroy]

  def index
    @query = params[:q]
    @sort = sort_column(Artist, default: "created_at")
    @direction = sort_direction
    scope = Current.user.artists.music.includes(albums: {cover_image_attachment: :blob})
      .search(@query)
      .order(@sort => @direction)
    @pagy, @artists = pagy(:offset, scope)
  end

  def show
    @artist = Current.user.artists.find(params[:id])
    @albums = @artist.albums.includes(:tracks, cover_image_attachment: :blob).order(:year)
  end

  def discography
    @artist = Current.user.artists.find(params[:id])
    @albums = @artist.albums.includes(:tracks, cover_image_attachment: :blob).order(:year)

    if @artist.musicbrainz_artist_id.present?
      mb_discography = MusicBrainzDiscographyService.call(@artist.musicbrainz_artist_id)
      @entries = DiscographyMergeService.call(@artist, @albums, mb_discography)
    else
      @entries = @albums.map { |a| {type: :owned, album: a, year: a.year} }
    end
  rescue MusicBrainzService::Error => e
    Rails.logger.error("Discography fetch failed for artist #{@artist.id}: #{e.message}")
    @entries = @albums.map { |a| {type: :owned, album: a, year: a.year} }
  end

  def missing_album
    @artist = Current.user.artists.find(params[:id])
    @mbid = params[:mbid]
    @album_data = MusicBrainzDiscographyService.fetch_release_group_tracks(@mbid)
    @cover_art_url = "https://coverartarchive.org/release-group/#{@mbid}/front-500"
  end

  def import_search
    @artist = Current.user.artists.find(params[:id])
    @query = params[:q].to_s.strip
    service = YoutubeAPIService.new(api_key: Current.user.youtube_api_key)
    @results = service.search_playlists(@query, max_results: 6)
  rescue YoutubeAPIService::Error => e
    @results = []
    @error = e.message
  end

  def import_album
    @artist = Current.user.artists.find(params[:id])
    url = params[:youtube_url]

    YoutubeImportJob.perform_later(
      url,
      category: "music",
      download: true,
      user_id: Current.user.id,
      artist_id: @artist.id
    )

    redirect_to @artist, notice: "Importing album in background..."
  end

  def edit
    @artist = Current.user.artists.find(params[:id])
  end

  def update
    @artist = Current.user.artists.find(params[:id])
    if @artist.update(artist_params)
      redirect_to @artist, notice: "Artist updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @artist = Current.user.artists.find(params[:id])
    @artist.destroy
    redirect_to artists_path, notice: "Artist deleted."
  end

  private

  def artist_params
    params.require(:artist).permit(:name, :category)
  end
end
