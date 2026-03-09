class StationUrlImportService
  STREAM_EXTENSIONS = /\.(mp3|aac|ogg|m3u8|pls|m3u|flac|opus)(\?|$)/i
  STREAM_CONTENT_TYPES = %w[audio/mpeg audio/aac audio/ogg application/vnd.apple.mpegurl audio/x-mpegurl].freeze

  # Known JSON keys in page source that contain stream URLs
  STREAM_JSON_KEYS = %w[secure_shoutcast_stream secure_hls_stream shoutcast_stream hls_stream stream_url streamUrl].freeze

  def initialize(url)
    @url = url.strip
  end

  def call
    response = HTTP.follow(max_hops: 5)
      .headers("User-Agent" => "Mozilla/5.0 (compatible; SynthWaves.fm/1.0)")
      .timeout(connect: 5, read: 15)
      .get(@url)

    content_type = response.content_type.mime_type

    # If the URL itself is a direct stream, create station from it
    if stream_content_type?(content_type)
      return create_station(name: domain_name, stream_url: @url, homepage_url: @url)
    end

    html = response.body.to_s
    doc = Nokogiri::HTML(html)

    name = extract_name(doc)
    favicon = extract_favicon(doc)

    # Try scraping the page first — embedded data is most reliable
    stream_url = extract_stream_url(doc, html)

    if stream_url.present?
      return create_station(
        name: name.presence || domain_name,
        stream_url: stream_url,
        homepage_url: @url,
        favicon_url: favicon
      )
    end

    # Fall back to Radio Browser API
    if name.present?
      api_station = search_radio_browser(name)
      if api_station
        return create_station_from_api(api_station, homepage_url: @url, favicon_url: favicon)
      end
    end

    {error: "Could not find a stream URL on this page. Try adding the direct stream URL instead."}
  end

  private

  def domain_name
    URI.parse(@url).host&.sub(/\Awww\./, "")&.titleize
  rescue URI::InvalidURIError
    "Unknown Station"
  end

  def stream_content_type?(content_type)
    STREAM_CONTENT_TYPES.any? { |ct| content_type&.include?(ct) }
  end

  def extract_name(doc)
    og_title = doc.at('meta[property="og:title"]')&.[]("content")
    return og_title if og_title.present?

    title = doc.at("title")&.text&.strip
    return title if title.present?

    nil
  end

  def extract_stream_url(doc, html)
    # Check <audio> source tags
    doc.css("audio source, audio").each do |el|
      src = el["src"]
      return absolute_url(src) if src.present? && src.match?(STREAM_EXTENSIONS)
    end

    # Check for known stream JSON keys embedded in page source (iHeart, TuneIn, etc.)
    STREAM_JSON_KEYS.each do |key|
      html.scan(/"#{key}"\s*:\s*"(https?:\/\/[^"]+)"/).flatten.each do |url|
        return url
      end
    end

    # Check <a> tags linking to stream files
    doc.css("a[href]").each do |el|
      href = el["href"]
      return absolute_url(href) if href.present? && href.match?(STREAM_EXTENSIONS)
    end

    # Scan page source for URLs with stream file extensions
    html.scan(%r{(https?://[^\s"'<>]+?\.(?:mp3|aac|ogg|m3u8|pls)(?:\?[^\s"'<>]*)?)}).flatten.each do |url|
      return url
    end

    nil
  end

  def extract_favicon(doc)
    # Check for apple-touch-icon first (higher resolution)
    icon = doc.at('link[rel="apple-touch-icon"]')&.[]("href")
    return absolute_url(icon) if icon.present?

    # Standard favicon
    icon = doc.at('link[rel="icon"]')&.[]("href")
    return absolute_url(icon) if icon.present?

    icon = doc.at('link[rel="shortcut icon"]')&.[]("href")
    return absolute_url(icon) if icon.present?

    # og:image as fallback
    doc.at('meta[property="og:image"]')&.[]("content")
  end

  def absolute_url(path)
    return nil if path.blank?
    return path if path.start_with?("http")

    base = URI.parse(@url)
    URI.join("#{base.scheme}://#{base.host}", path).to_s
  rescue URI::InvalidURIError
    nil
  end

  def search_radio_browser(name)
    candidates = [name]
    # Try the part before " - " or " | " (e.g. "BIG 105.9 - Rock's Greatest Hits" -> "BIG 105.9")
    candidates << name.split(/\s*[-–|]\s*/).first if name.match?(/[-–|]/)
    # Try the domain name (e.g. "big1059.iheart.com" -> "big1059")
    domain = URI.parse(@url).host&.sub(/\Awww\./, "")&.split(".")&.first
    candidates << domain if domain.present?

    api = RadioBrowserService.new
    candidates.compact.uniq.each do |query|
      results = api.search(query, limit: 5)
      match = results.find { |s| s["url_resolved"].present? || s["url"].present? }
      return match if match
    end

    nil
  rescue HTTP::Error, HTTP::TimeoutError
    nil
  end

  def create_station_from_api(api_station, homepage_url:, favicon_url:)
    station = InternetRadioStation.find_or_initialize_by(uuid: api_station["stationuuid"])
    station.assign_attributes(
      name: api_station["name"],
      stream_url: api_station["url_resolved"].presence || api_station["url"],
      homepage_url: homepage_url,
      favicon_url: favicon_url.presence || api_station["favicon"].presence,
      country: api_station["country"].presence,
      country_code: api_station["countrycode"].presence,
      language: api_station["language"].presence,
      tags: api_station["tags"].presence,
      codec: api_station["codec"].presence,
      bitrate: api_station["bitrate"].to_i,
      votes: api_station["votes"].to_i
    )
    station.save!
    {station: station}
  end

  def create_station(name:, stream_url:, homepage_url: nil, favicon_url: nil)
    station = InternetRadioStation.create!(
      name: name,
      stream_url: stream_url,
      homepage_url: homepage_url,
      favicon_url: favicon_url
    )
    {station: station}
  end
end
