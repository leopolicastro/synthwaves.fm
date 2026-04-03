class MusicBrainzService
  BASE_URL = "https://musicbrainz.org/ws/2"
  USER_AGENT = "SynthwavesFM/1.0 (https://synthwaves.fm)"
  MIN_REQUEST_INTERVAL = 1.1

  class Error < StandardError; end

  def search_recording(artist:, title:, limit: 5)
    query = %(artist:"#{escape(artist)}" AND recording:"#{escape(title)}")
    data = get("/recording", query: query, limit: limit)

    (data["recordings"] || []).map { |r| parse_recording(r) }
  end

  def search_recording_by_isrc(isrc:)
    data = get("/recording", query: %(isrc:"#{escape(isrc)}"), limit: 5)

    (data["recordings"] || []).map { |r| parse_recording(r) }
  end

  private

  def get(path, query:, limit:)
    rate_limit!

    response = HTTP.headers("User-Agent" => USER_AGENT, "Accept" => "application/json")
      .get("#{BASE_URL}#{path}", params: {query: query, limit: limit, fmt: "json"})

    unless response.status.success?
      raise Error, "MusicBrainz API error (#{response.status}): #{response.body.to_s.truncate(200)}"
    end

    JSON.parse(response.body.to_s)
  rescue HTTP::Error => e
    raise Error, "MusicBrainz API connection error: #{e.message}"
  end

  def rate_limit!
    sleep(MIN_REQUEST_INTERVAL)
  end

  def parse_recording(recording)
    artist_credit = (recording["artist-credit"] || []).first || {}
    artist = artist_credit["artist"] || {}
    releases = (recording["releases"] || []).map { |r| parse_release(r) }

    {
      mbid: recording["id"],
      title: recording["title"],
      artist_name: artist_credit["name"] || artist["name"],
      artist_mbid: artist["id"],
      duration_ms: recording["length"],
      tags: parse_tags(recording["tags"]),
      releases: releases
    }
  end

  def parse_release(release)
    {
      mbid: release["id"],
      title: release["title"],
      date: release["date"],
      country: release["country"]
    }
  end

  def parse_tags(tags)
    return [] if tags.blank?

    tags
      .select { |t| t["count"].to_i >= 1 }
      .sort_by { |t| -t["count"].to_i }
      .map { |t| t["name"] }
  end

  def escape(text)
    text.to_s.gsub(/([+\-&|!(){}\[\]^"~*?:\\])/, '\\\\\1')
  end
end
