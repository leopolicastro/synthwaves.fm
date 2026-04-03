class InternetRadioStreamsController < ApplicationController
  include ActionController::Live

  def show
    station = InternetRadioStation.find(params[:internet_radio_station_id])

    content_type = case station.codec&.downcase
    when "aac" then "audio/aac"
    when "ogg" then "audio/ogg"
    else "audio/mpeg"
    end

    response.headers["Content-Type"] = content_type
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
    logger.error "Stream proxy error for internet radio station #{station&.id}: #{e.message}"
    head :bad_gateway unless response.committed?
  ensure
    response.stream.close
  end
end
