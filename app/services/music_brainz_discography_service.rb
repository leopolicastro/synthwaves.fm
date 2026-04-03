class MusicBrainzDiscographyService
  CACHE_TTL = 7.days

  def self.call(artist_mbid)
    new(artist_mbid).call
  end

  def self.fetch_release_group_tracks(release_group_mbid)
    new(nil).fetch_release_group_tracks(release_group_mbid)
  end

  def self.fetch_release_tracks(release_mbid)
    new(nil).fetch_release_tracks(release_mbid)
  end

  def initialize(artist_mbid)
    @artist_mbid = artist_mbid
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_discography
    end
  end

  def fetch_release_tracks(release_mbid)
    Rails.cache.fetch("musicbrainz:release_tracks:#{release_mbid}", expires_in: CACHE_TTL) do
      release_detail = mb_get("/release/#{release_mbid}", params: {inc: "recordings", fmt: "json"})

      media = release_detail["media"] || []
      tracks = media.flat_map do |medium|
        (medium["tracks"] || []).map do |track|
          recording = track["recording"] || {}
          {
            position: track["position"],
            title: recording["title"] || track["title"],
            duration_ms: recording["length"] || track["length"]
          }
        end
      end

      year = release_detail["date"]&.slice(0, 4)&.to_i
      year = nil if year&.zero?

      {title: release_detail["title"], year: year, tracks: tracks}
    end
  end

  def fetch_release_group_tracks(release_group_mbid)
    Rails.cache.fetch("musicbrainz:release_group_tracks:#{release_group_mbid}", expires_in: CACHE_TTL) do
      fetch_tracks_for_release_group(release_group_mbid)
    end
  end

  private

  def cache_key
    "musicbrainz:discography:#{@artist_mbid}"
  end

  def fetch_discography
    release_groups = []
    offset = 0
    limit = 100

    loop do
      data = browse_release_groups(offset: offset, limit: limit)
      groups = data["release-groups"] || []
      release_groups.concat(groups.map { |rg| parse_release_group(rg) })

      total = data["release-group-count"].to_i
      offset += limit
      break if offset >= total || groups.empty?
    end

    release_groups.sort_by { |rg| [rg[:year] || 9999, rg[:title]] }
  end

  def browse_release_groups(offset:, limit:)
    mb_get("/release-group", params: {
      artist: @artist_mbid, type: "album", fmt: "json", limit: limit, offset: offset
    })
  end

  def parse_release_group(rg)
    year = rg["first-release-date"]&.slice(0, 4)&.to_i
    year = nil if year&.zero?

    {
      mbid: rg["id"],
      title: rg["title"],
      year: year,
      type: rg["primary-type"] || "Album",
      cover_art_url: "https://coverartarchive.org/release-group/#{rg["id"]}/front-250"
    }
  end

  def fetch_tracks_for_release_group(release_group_mbid)
    releases_data = mb_get("/release", params: {
      "release-group" => release_group_mbid, "status" => "official", "fmt" => "json", "limit" => 10
    })

    releases = releases_data["releases"] || []
    return {release_mbid: nil, title: nil, year: nil, tracks: []} if releases.empty?

    release = pick_best_release(releases)
    release_detail = mb_get("/release/#{release["id"]}", params: {inc: "recordings", fmt: "json"})

    media = release_detail["media"] || []
    tracks = media.flat_map do |medium|
      (medium["tracks"] || []).map do |track|
        recording = track["recording"] || {}
        {
          position: track["position"],
          title: recording["title"] || track["title"],
          duration_ms: recording["length"] || track["length"]
        }
      end
    end

    year = release_detail["date"]&.slice(0, 4)&.to_i
    year = nil if year&.zero?

    {
      release_mbid: release_detail["id"],
      title: release_detail["title"],
      year: year,
      tracks: tracks
    }
  end

  def pick_best_release(releases)
    official = releases.select { |r| r["status"] == "Official" }
    candidates = official.any? ? official : releases

    dated = candidates.select { |r| r["date"].present? }
    return dated.min_by { |r| r["date"] } if dated.any?

    candidates.first
  end

  def mb_get(path, params:)
    sleep(MusicBrainzService::MIN_REQUEST_INTERVAL)

    response = HTTP.headers(
      "User-Agent" => MusicBrainzService::USER_AGENT,
      "Accept" => "application/json"
    ).get("#{MusicBrainzService::BASE_URL}#{path}", params: params)

    unless response.status.success?
      raise MusicBrainzService::Error, "MusicBrainz API error (#{response.status}): #{response.body.to_s.truncate(200)}"
    end

    JSON.parse(response.body.to_s)
  rescue HTTP::Error => e
    raise MusicBrainzService::Error, "MusicBrainz API connection error: #{e.message}"
  end
end
