class YoutubeVideoImportHandler
  class Error < StandardError; end

  Result = Struct.new(:video, :status, keyword_init: true)

  def self.call(url:, user:)
    new(url: url, user: user).call
  end

  def initialize(url:, user:)
    @url = url
    @user = user
  end

  def call
    validate_url!

    existing = Video.find_by(youtube_video_id: video_id)
    return Result.new(video: existing, status: :existing) if existing

    details = fetch_video_details
    video = Video.create!(
      title: details[:title],
      user: @user,
      duration: details[:duration],
      youtube_video_id: video_id,
      status: "processing"
    )

    VideoDownloadJob.perform_later(video.id, @url, user_id: @user.id)
    Result.new(video: video, status: :created)
  end

  private

  def validate_url!
    if YoutubeUrlParser.playlist_url?(@url)
      raise Error, "Video download is not supported for playlists. Please use a single video URL."
    end
    unless YoutubeUrlParser.video_url?(@url)
      raise Error, "Please enter a valid YouTube URL."
    end
  end

  def video_id
    @video_id ||= YoutubeUrlParser.extract_video_id(@url)
  end

  def fetch_video_details
    if @user.youtube_api_key.present?
      api = YoutubeAPIService.new(api_key: @user.youtube_api_key)
      details = api.fetch_video_details([video_id]).first
      raise YoutubeAPIService::Error, "Video not found" if details.nil?
      details
    else
      MediaDownloadService.fetch_metadata(@url)
    end
  end
end
