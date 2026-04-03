class ExternalStreamsController < ApplicationController
  def index
    @external_streams = Current.user.external_streams.order(created_at: :desc)
  end

  def new
    @external_stream = ExternalStream.new
  end

  def create
    @external_stream = Current.user.external_streams.new(external_stream_params)

    case @external_stream.source_type
    when "youtube"
      handle_youtube_creation
    when "stream"
      handle_stream_creation
    end

    if @external_stream.errors.any?
      render :new, status: :unprocessable_content
    elsif @external_stream.save
      redirect_to external_streams_path, notice: "Radio station added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    external_stream = Current.user.external_streams.find(params[:id])
    external_stream.destroy
    redirect_to external_streams_path, notice: "Radio station removed."
  end

  private

  def external_stream_params
    params.require(:external_stream).permit(:name, :youtube_url, :stream_url, :source_type)
  end

  def handle_youtube_creation
    video_id = YoutubeUrlParser.extract_video_id(@external_stream.youtube_url)
    if video_id.present?
      @external_stream.youtube_video_id = video_id
      fetch_oembed_metadata
    end
  end

  def handle_stream_creation
    url = @external_stream.stream_url
    return if url.blank?

    result = StreamUrlResolver.call(url)

    if result.error.present?
      @external_stream.errors.add(:stream_url, result.error)
      return
    end

    if result.stream_url != url
      @external_stream.original_url = url
      @external_stream.stream_url = result.stream_url
    end

    @external_stream.name = result.name if @external_stream.name.blank? && result.name.present?
  end

  def fetch_oembed_metadata
    response = HTTP.get("https://www.youtube.com/oembed", params: {
      url: @external_stream.youtube_url,
      format: "json"
    })

    if response.status.success?
      data = response.parse
      @external_stream.name = data["title"] if @external_stream.name.blank?
      @external_stream.thumbnail_url = data["thumbnail_url"]
    end
  rescue HTTP::Error
    # oEmbed fetch failed — user can still provide name manually
  end
end
