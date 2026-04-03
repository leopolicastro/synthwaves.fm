class AlbumsController < ApplicationController
  include Orderable
  include AdminAuthorization

  before_action :require_admin, only: [:edit, :destroy, :merge]

  def index
    @query = params[:q]
    @sort = sort_column(Album, default: "created_at")
    @direction = sort_direction
    scope = Current.user.albums.music.includes(:artist, cover_image_attachment: :blob)
      .search(@query)
      .order(@sort => @direction)
    @pagy, @albums = pagy(:offset, scope)
  end

  def show
    @album = Current.user.albums.includes(:artist, tracks: :artist).find(params[:id])
    @sort = sort_column(Track, default: "disc_number")
    @direction = sort_direction(default: "asc")

    scope = if @sort == "disc_number"
      @album.tracks.order(disc_number: @direction, track_number: @direction)
    else
      @album.tracks.order(@sort => @direction)
    end

    @total_tracks = scope.count
    @total_duration = @album.tracks.sum(:duration)
    @all_tracks = @album.tracks
    @pagy, @tracks = pagy(:offset, scope)
    @favorited_track_ids = Current.user.favorited_ids_for("Track")
  end

  def edit
    @album = Current.user.albums.find(params[:id])
    @artists = Current.user.artists.order(:name)
  end

  def destroy
    @album = Current.user.albums.find(params[:id])
    artist = @album.artist
    @album.destroy
    redirect_to artist_path(artist), notice: "Album deleted."
  end

  def merge
    @album = Current.user.albums.find(params[:id])
    source = Current.user.albums.find(params[:source_album_id])
    AlbumMergeService.call(target: @album, source: source)
    redirect_to @album, notice: "Merged \"#{source.title}\" into this album."
  rescue AlbumMergeService::Error => e
    redirect_to @album, alert: e.message
  end

  def refresh
    album = Current.user.albums.find(params[:id])

    unless album.youtube_playlist_url.present?
      redirect_to album, alert: "This album has no YouTube playlist URL to refresh from."
      return
    end

    track_count_before = album.tracks.count
    YoutubePlaylistImportService.call(album.youtube_playlist_url, category: album.artist.category, api_key: Current.user.youtube_api_key, user: Current.user)
    new_count = album.tracks.reload.count - track_count_before

    if new_count > 0
      redirect_to album, notice: "#{new_count} new #{"episode".pluralize(new_count)} added."
    else
      redirect_to album, notice: "No new episodes found."
    end
  rescue YoutubePlaylistImportService::Error => e
    redirect_to album, alert: "Refresh failed: #{e.message}"
  end

  def download_audio
    album = Current.user.albums.find(params[:id])

    tracks = album.tracks.where.not(youtube_video_id: [nil, ""]).reject { |t| t.audio_file.attached? }

    if album.tracks.where.not(youtube_video_id: [nil, ""]).none?
      redirect_to album, alert: "No YouTube tracks to download."
      return
    end

    if tracks.empty?
      redirect_to album, notice: "All tracks already have audio."
      return
    end

    tracks.each do |track|
      url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
      MediaDownloadJob.perform_later(track.id, url, user_id: Current.user.id)
    end

    redirect_to album, notice: "Downloading audio for #{tracks.size} #{"track".pluralize(tracks.size)}."
  end

  def update
    @album = Current.user.albums.find(params[:id])
    if @album.update(album_params)
      redirect_to @album, notice: "Album updated."
    else
      @artists = Current.user.artists.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def fetch_cover
    album = Current.user.albums.find(params[:id])

    result = CoverArtSearchService.call(album)

    if result == :not_found
      redirect_to album, alert: "No cover art found."
    else
      redirect_to album, notice: "Cover art updated from #{result} source."
    end
  end

  def missing_tracks
    @album = Current.user.albums.includes(:artist, tracks: :artist).find(params[:id])
    tracks = @album.tracks.order(disc_number: :asc, track_number: :asc)

    if @album.musicbrainz_release_id.present?
      mb_data = MusicBrainzDiscographyService.fetch_release_tracks(@album.musicbrainz_release_id)
      @entries = AlbumTracksMergeService.call(tracks, mb_data[:tracks])
    else
      @entries = []
    end
  rescue MusicBrainzService::Error => e
    Rails.logger.error("Missing tracks fetch failed for album #{@album.id}: #{e.message}")
    @entries = []
  end

  def import_track
    @album = Current.user.albums.includes(:artist).find(params[:id])
    title = params[:track_title].to_s.strip
    query = "#{@album.artist.name} #{title}"

    api_key = Current.user.youtube_api_key
    service = YoutubeAPIService.new(api_key: api_key)
    results = service.search_videos(query, max_results: 1)

    if results.empty?
      redirect_to @album, alert: "No YouTube results found for \"#{title}\"."
      return
    end

    video = results.first
    track = Current.user.tracks.create!(
      title: title,
      artist: @album.artist,
      album: @album,
      youtube_video_id: video[:video_id],
      duration: video[:duration]
    )

    video_url = "https://www.youtube.com/watch?v=#{video[:video_id]}"
    MediaDownloadJob.perform_later(track.id, video_url, user_id: Current.user.id)

    redirect_to @album, notice: "Downloading \"#{title}\"..."
  end

  def import_missing_tracks
    @album = Current.user.albums.includes(:artist, tracks: :artist).find(params[:id])

    unless @album.musicbrainz_release_id.present?
      redirect_to @album, alert: "No MusicBrainz data available for this album."
      return
    end

    mb_data = MusicBrainzDiscographyService.fetch_release_tracks(@album.musicbrainz_release_id)
    owned_tracks = @album.tracks.order(disc_number: :asc, track_number: :asc)
    entries = AlbumTracksMergeService.call(owned_tracks, mb_data[:tracks])
    missing = entries.select { |e| e[:type] == :missing }

    if missing.empty?
      redirect_to @album, notice: "No missing tracks to download."
      return
    end

    api_key = Current.user.youtube_api_key
    service = YoutubeAPIService.new(api_key: api_key)

    imported = 0
    missing.each do |entry|
      query = "#{@album.artist.name} #{entry[:title]}"
      results = service.search_videos(query, max_results: 1)
      next if results.empty?

      video = results.first
      track = Current.user.tracks.create!(
        title: entry[:title],
        artist: @album.artist,
        album: @album,
        track_number: entry[:position],
        youtube_video_id: video[:video_id],
        duration: video[:duration]
      )

      video_url = "https://www.youtube.com/watch?v=#{video[:video_id]}"
      MediaDownloadJob.perform_later(track.id, video_url, user_id: Current.user.id)
      imported += 1
    end

    redirect_to @album, notice: "Downloading #{imported} missing #{"track".pluralize(imported)}..."
  end

  def create_playlist
    album = Current.user.albums.find(params[:id])
    tracks = album.tracks.order(:disc_number, :track_number)
    playlist = Current.user.playlists.create!(name: album.title)

    tracks.each_with_index do |track, index|
      playlist.playlist_tracks.create!(track: track, position: index + 1)
    end

    redirect_to playlist, notice: "Playlist created from #{album.title}"
  end

  private

  def album_params
    params.require(:album).permit(:title, :year, :genre, :artist_id, :youtube_playlist_url)
  end
end
