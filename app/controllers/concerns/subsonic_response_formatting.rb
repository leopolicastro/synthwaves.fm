require "builder"

module SubsonicResponseFormatting
  extend ActiveSupport::Concern

  SUBSONIC_API_VERSION = "1.16.1"
  SERVER_NAME = "synthwaves.fm"

  private

  def render_subsonic(data = {})
    response_hash = {
      status: "ok",
      version: SUBSONIC_API_VERSION,
      type: SERVER_NAME,
      serverVersion: "0.1.0",
      openSubsonic: true
    }.merge(data)

    if json_format?
      render json: {"subsonic-response" => response_hash}
    else
      render xml: build_xml(response_hash)
    end
  end

  def render_subsonic_error(code, message)
    response_hash = {
      status: "failed",
      version: SUBSONIC_API_VERSION,
      type: SERVER_NAME,
      error: {code: code, message: message}
    }

    if json_format?
      render json: {"subsonic-response" => response_hash}
    else
      render xml: build_xml(response_hash)
    end
  end

  def json_format?
    params[:f] == "json"
  end

  def build_xml(hash)
    builder = Builder::XmlMarkup.new
    builder.instruct!
    build_xml_element(builder, "subsonic-response", hash)
    builder.target!
  end

  def build_xml_element(builder, name, value)
    case value
    when Hash
      attrs = {}
      children = {}
      value.each do |k, v|
        if v.is_a?(Hash) || v.is_a?(Array)
          children[k] = v
        else
          attrs[k] = v
        end
      end
      builder.tag!(name, attrs) do
        children.each { |k, v| build_xml_element(builder, k.to_s, v) }
      end
    when Array
      value.each { |item| build_xml_element(builder, name, item) }
    else
      builder.tag!(name, value)
    end
  end

  def track_to_child(track)
    Subsonic::TrackSerializer.to_child(track)
  end

  def album_to_entry(album)
    Subsonic::AlbumSerializer.to_entry(album)
  end

  def video_to_entry(video)
    Subsonic::VideoSerializer.to_entry(video)
  end
end
