class YoutubeImportsController < ApplicationController
  include FeatureFlagged
  require_feature :youtube_import

  def new
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
    url = params[:youtube_url]
    category = params[:category].presence || "music"
    media_type = params[:media_type].presence || "audio"

    if media_type == "video"
      handle_video_import(url)
    elsif YoutubeUrlParser.playlist_url?(url)
      YoutubeImportJob.perform_later(url, category: category, download: true, user_id: Current.user.id)
      redirect_to library_path, notice: "Playlist import started! Audio will be downloaded in the background."
    elsif YoutubeUrlParser.video_url?(url)
      track = YoutubeVideoImportService.call(url, category: category, api_key: Current.user.youtube_api_key)
      MediaDownloadJob.perform_later(track.id, url, user_id: Current.user.id)
      redirect_to album_path(track.album), notice: "Video imported! Audio download started in the background."
    else
      flash.now[:alert] = "Please enter a valid YouTube URL."
      render :new, status: :unprocessable_content
    end
  rescue YoutubeVideoImportService::Error, YoutubeAPIService::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  end

  private

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

    api = YoutubeAPIService.new(api_key: Current.user.youtube_api_key)
    details = api.fetch_video_details([video_id]).first
    raise YoutubeAPIService::Error, "Video not found" if details.nil?

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
