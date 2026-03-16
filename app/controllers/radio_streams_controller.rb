class RadioStreamsController < ApplicationController
  include ActionController::Live
  include FeatureFlagged

  require_feature :youtube_radio

  def show
    station = RadioStation.find(params[:radio_station_id])

    unless station.stream?
      head :not_found
      return
    end

    response.headers["Content-Type"] = "audio/mpeg"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["Cache-Control"] = "no-cache"

    upstream = HTTP
      .headers("User-Agent" => "Mozilla/5.0 (compatible; synthwaves.fm/1.0)")
      .follow(max_hops: 5)
      .timeout(connect: 5, read: 30)
      .get(station.stream_url)

    upstream.body.each do |chunk|
      response.stream.write(chunk)
    end
  rescue ActionController::Live::ClientDisconnected
    # Client disconnected — expected for streams
  rescue HTTP::Error => e
    logger.error "Stream proxy error for station #{station&.id}: #{e.message}"
    head :bad_gateway unless response.committed?
  ensure
    response.stream.close
  end
end
