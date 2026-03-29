class YoutubeImportsController < ApplicationController
  include FeatureFlagged

  require_feature :youtube_import

  def new
    @playlists = Current.user.playlists.order(:name)
  end

  def search
    @query = params[:q].to_s.strip
    @results = @query.present? ? YoutubeAPIService.new(api_key: Current.user.youtube_api_key).search_videos(@query) : []
    render partial: "youtube_imports/search_results"
  rescue YoutubeAPIService::Error => e
    @results = []
    @error = e.message
    render partial: "youtube_imports/search_results"
  end

  def create
    @playlists = Current.user.playlists.order(:name)
    url = params[:youtube_url]
    category = params[:category].presence || "music"
    media_type = params[:media_type].presence || "audio"

    if media_type == "video"
      handle_video_import(url)
    elsif YoutubeUrlParser.playlist_url?(url)
      YoutubeImportJob.perform_later(url, category: category, download: true, user_id: Current.user.id,
        playlist_id: resolve_playlist_id, new_playlist_name: params[:new_playlist_name].presence)
      redirect_to library_path, notice: "Playlist import started! Audio will be downloaded in the background."
    elsif YoutubeUrlParser.video_url?(url)
      track = YoutubeVideoImportService.call(url, category: category, api_key: Current.user.youtube_api_key, user: Current.user)
      MediaDownloadJob.perform_later(track.id, url, user_id: Current.user.id)
      add_track_to_playlist(track)
      redirect_to album_path(track.album), notice: "Video imported! Audio download started in the background."
    else
      flash.now[:alert] = "Please enter a valid YouTube URL."
      render :new, status: :unprocessable_content
    end
  rescue YoutubeVideoImportService::Error, YoutubeAPIService::Error, MediaDownloadService::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  end

  private

  def resolve_playlist_id
    id = params[:playlist_id]
    id == "new" ? nil : id.presence&.to_i
  end

  def add_track_to_playlist(track)
    playlist = if params[:playlist_id] == "new" && params[:new_playlist_name].present?
      Current.user.playlists.create!(name: params[:new_playlist_name])
    elsif params[:playlist_id].present? && params[:playlist_id] != "new"
      Current.user.playlists.find_by(id: params[:playlist_id])
    end

    return unless playlist

    unless playlist.playlist_tracks.exists?(track: track)
      next_position = (playlist.playlist_tracks.maximum(:position) || 0) + 1
      playlist.playlist_tracks.create!(track: track, position: next_position)
    end
  end

  def handle_video_import(url)
    if YoutubeUrlParser.playlist_url?(url)
      flash.now[:alert] = "Video download is not supported for playlists. Please use a single video URL."
      render :new, status: :unprocessable_content
      return
    end

    unless YoutubeUrlParser.video_url?(url)
      flash.now[:alert] = "Please enter a valid YouTube URL."
      render :new, status: :unprocessable_content
      return
    end

    video_id = YoutubeUrlParser.extract_video_id(url)
    existing = Video.find_by(youtube_video_id: video_id)
    if existing
      redirect_to video_path(existing), notice: "This video has already been imported."
      return
    end

    details = if Current.user.youtube_api_key.present?
      api = YoutubeAPIService.new(api_key: Current.user.youtube_api_key)
      api.fetch_video_details([video_id]).first.tap do |d|
        raise YoutubeAPIService::Error, "Video not found" if d.nil?
      end
    else
      MediaDownloadService.fetch_metadata(url)
    end

    video = Video.create!(
      title: details[:title],
      user: Current.user,
      duration: details[:duration],
      youtube_video_id: video_id,
      status: "processing"
    )

    VideoDownloadJob.perform_later(video.id, url, user_id: Current.user.id)
    redirect_to video_path(video), notice: "Video import started! It will be ready once the download completes."
  end
end
