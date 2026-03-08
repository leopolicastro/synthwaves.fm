require "builder"

module SubsonicResponseFormatting
  extend ActiveSupport::Concern

  SUBSONIC_API_VERSION = "1.16.1"
  SERVER_NAME = "GroovyTunes"

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
    {
      id: track.id.to_s,
      parent: track.album_id.to_s,
      isDir: false,
      title: track.title,
      album: track.album.title,
      artist: track.artist.name,
      track: track.track_number,
      year: track.album.year,
      genre: track.album.genre,
      size: track.file_size,
      contentType: audio_content_type(track.file_format),
      suffix: track.file_format,
      duration: track.duration&.to_i,
      bitRate: track.bitrate,
      albumId: track.album_id.to_s,
      artistId: track.artist_id.to_s,
      type: "music"
    }.compact
  end

  def album_to_entry(album)
    {
      id: album.id.to_s,
      name: album.title,
      artist: album.artist.name,
      artistId: album.artist_id.to_s,
      songCount: album.tracks.size,
      duration: album.tracks.sum(:duration).to_i,
      year: album.year,
      genre: album.genre,
      coverArt: album.id.to_s
    }.compact
  end

  def audio_content_type(format)
    {
      "mp3" => "audio/mpeg",
      "flac" => "audio/flac",
      "ogg" => "audio/ogg",
      "m4a" => "audio/mp4",
      "aac" => "audio/mp4",
      "opus" => "audio/opus"
    }[format.to_s.downcase] || "audio/mpeg"
  end
end
