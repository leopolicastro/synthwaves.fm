class AppleMusicService
  MUSICKIT_BASE_URL = "https://api.music.apple.com/v1"

  class Error < StandardError; end

  def initialize(storefront: "us")
    @storefront = storefront
  end

  def search_song(artist:, title:, limit: 5)
    term = "#{artist} #{title}".strip
    search_via_musickit(term: term, limit: limit)
  end

  private

  def search_via_musickit(term:, limit:)
    token = AppleMusicTokenService.token
    response = HTTP.auth("Bearer #{token}")
      .get("#{MUSICKIT_BASE_URL}/catalog/#{@storefront}/search", params: {term: term, types: "songs", limit: limit})

    unless response.status.success?
      raise Error, "Apple Music API error (#{response.status}): #{response.body.to_s.truncate(200)}"
    end

    data = JSON.parse(response.body.to_s)
    (data.dig("results", "songs", "data") || []).map { |song| parse_musickit_song(song) }
  rescue HTTP::Error => e
    raise Error, "Apple Music API connection error: #{e.message}"
  end

  def parse_musickit_song(song)
    attrs = song["attributes"] || {}
    {
      apple_music_id: song["id"],
      name: attrs["name"],
      artist_name: attrs["artistName"],
      album_name: attrs["albumName"],
      genre_names: attrs["genreNames"] || [],
      isrc: attrs["isrc"],
      content_rating: attrs["contentRating"],
      release_date: attrs["releaseDate"],
      duration_ms: attrs["durationInMillis"],
      disc_number: attrs["discNumber"],
      track_number: attrs["trackNumber"],
      composer_name: attrs["composerName"]
    }
  end
end
