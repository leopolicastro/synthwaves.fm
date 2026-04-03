class YoutubeAPIService
  BASE_URL = "https://www.googleapis.com/youtube/v3"

  class Error < StandardError; end

  def initialize(api_key:)
    @api_key = api_key
    raise Error, "YouTube API key not configured" if @api_key.blank?
  end

  def fetch_playlist_info(playlist_id)
    response = get("playlists", {
      part: "snippet,contentDetails",
      id: playlist_id
    })

    item = response["items"]&.first
    raise Error, "Playlist not found" if item.nil?

    {
      title: item.dig("snippet", "title"),
      channel_name: item.dig("snippet", "channelTitle"),
      thumbnail_url: best_thumbnail(item.dig("snippet", "thumbnails")),
      item_count: item.dig("contentDetails", "itemCount")
    }
  end

  def fetch_playlist_items(playlist_id)
    items = []
    page_token = nil

    loop do
      params = {
        part: "snippet",
        playlistId: playlist_id,
        maxResults: 50
      }
      params[:pageToken] = page_token if page_token

      response = get("playlistItems", params)

      response["items"]&.each do |item|
        snippet = item["snippet"]
        video_id = snippet.dig("resourceId", "videoId")
        next if video_id.blank?

        items << {
          video_id: video_id,
          title: snippet["title"],
          position: snippet["position"],
          thumbnail_url: best_thumbnail(snippet["thumbnails"])
        }
      end

      page_token = response["nextPageToken"]
      break if page_token.nil?
    end

    items
  end

  def fetch_video_details(video_ids)
    return [] if video_ids.empty?

    results = []

    video_ids.each_slice(50) do |batch|
      response = get("videos", {
        part: "snippet,contentDetails",
        id: batch.join(",")
      })

      response["items"]&.each do |item|
        results << {
          video_id: item["id"],
          title: item.dig("snippet", "title"),
          channel_name: item.dig("snippet", "channelTitle"),
          duration: parse_iso8601_duration(item.dig("contentDetails", "duration")),
          thumbnail_url: best_thumbnail(item.dig("snippet", "thumbnails"))
        }
      end
    end

    results
  end

  def search_playlists(query, max_results: 5)
    return [] if query.blank?

    response = get("search", {
      part: "snippet",
      type: "playlist",
      q: query,
      maxResults: max_results
    })

    (response["items"] || []).map do |item|
      {
        playlist_id: item.dig("id", "playlistId"),
        title: CGI.unescapeHTML(item.dig("snippet", "title").to_s),
        channel_name: item.dig("snippet", "channelTitle"),
        thumbnail_url: best_thumbnail(item.dig("snippet", "thumbnails"))
      }
    end
  end

  def search_videos(query, max_results: 5)
    return [] if query.blank?

    response = get("search", {
      part: "snippet",
      type: "video",
      q: query,
      maxResults: max_results
    })

    (response["items"] || []).map do |item|
      {
        video_id: item.dig("id", "videoId"),
        title: CGI.unescapeHTML(item.dig("snippet", "title").to_s),
        channel_name: item.dig("snippet", "channelTitle"),
        thumbnail_url: best_thumbnail(item.dig("snippet", "thumbnails"))
      }
    end
  end

  private

  def get(endpoint, params)
    url = "#{BASE_URL}/#{endpoint}"
    response = HTTP.get(url, params: params.merge(key: @api_key))

    unless response.status.success?
      body = response.parse
      message = body.dig("error", "message") || "YouTube API error (#{response.status})"
      raise Error, message
    end

    response.parse
  end

  def best_thumbnail(thumbnails)
    return nil if thumbnails.nil?
    %w[high medium default].each do |quality|
      return thumbnails.dig(quality, "url") if thumbnails[quality]
    end
    nil
  end

  def parse_iso8601_duration(duration)
    return nil if duration.blank?

    match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
    return nil unless match

    hours = (match[1] || 0).to_i
    minutes = (match[2] || 0).to_i
    seconds = (match[3] || 0).to_i

    (hours * 3600 + minutes * 60 + seconds).to_f
  end
end
