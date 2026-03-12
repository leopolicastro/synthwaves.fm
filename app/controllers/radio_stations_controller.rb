class RadioStationsController < ApplicationController
  include FeatureFlagged
  require_feature :youtube_radio

  def index
    @radio_stations = RadioStation.order(created_at: :desc)
  end

  def new
    @radio_station = RadioStation.new
  end

  def create
    @radio_station = Current.user.radio_stations.new(radio_station_params)

    case @radio_station.source_type
    when "youtube"
      handle_youtube_creation
    when "stream"
      handle_stream_creation
    end

    if @radio_station.errors.any?
      render :new, status: :unprocessable_content
    elsif @radio_station.save
      redirect_to radio_stations_path, notice: "Radio station added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    radio_station = Current.user.radio_stations.find(params[:id])
    radio_station.destroy
    redirect_to radio_stations_path, notice: "Radio station removed."
  end

  private

  def radio_station_params
    params.require(:radio_station).permit(:name, :youtube_url, :stream_url, :source_type)
  end

  def handle_youtube_creation
    video_id = YoutubeUrlParser.extract_video_id(@radio_station.youtube_url)
    if video_id.present?
      @radio_station.youtube_video_id = video_id
      fetch_oembed_metadata
    end
  end

  def handle_stream_creation
    url = @radio_station.stream_url
    return if url.blank?

    result = StreamUrlResolver.call(url)

    if result.error.present?
      @radio_station.errors.add(:stream_url, result.error)
      return
    end

    if result.stream_url != url
      @radio_station.original_url = url
      @radio_station.stream_url = result.stream_url
    end

    @radio_station.name = result.name if @radio_station.name.blank? && result.name.present?
  end

  def fetch_oembed_metadata
    response = HTTP.get("https://www.youtube.com/oembed", params: {
      url: @radio_station.youtube_url,
      format: "json"
    })

    if response.status.success?
      data = response.parse
      @radio_station.name = data["title"] if @radio_station.name.blank?
      @radio_station.thumbnail_url = data["thumbnail_url"]
    end
  rescue HTTP::Error
    # oEmbed fetch failed — user can still provide name manually
  end
end
