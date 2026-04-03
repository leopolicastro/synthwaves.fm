class YoutubePlaylistImportService
  include ThumbnailAttachable

  class Error < StandardError; end

  def self.call(url, api_key:, user:, category: "music", artist: nil)
    new(url, category: category, api_key: api_key, user: user, artist: artist).call
  end

  def initialize(url, api_key:, user:, category: "music", artist: nil)
    @url = url
    @category = category
    @api_key = api_key
    @user = user
    @artist_override = artist
    @playlist_id = YoutubeUrlParser.extract_playlist_id(url)
    raise Error, "Invalid YouTube playlist URL" if @playlist_id.blank?
  end

  def call
    @playlist_info, @items = fetch_playlist_data
    return nil if @items.empty?

    @artist = find_or_create_artist
    @album = find_or_create_album
    import_tracks

    @album
  end

  private

  def find_or_create_artist
    @artist_override || @user.artists.find_or_create_by!(name: @playlist_info[:channel_name] || "Unknown Artist") do |a|
      a.category = @category
    end
  end

  def find_or_create_album
    album = @user.albums.find_or_create_by!(title: @playlist_info[:title], artist: @artist)
    album.update!(youtube_playlist_url: @url) if album.youtube_playlist_url.blank?

    if @playlist_info[:thumbnail_url].present? && !album.cover_image.attached?
      attach_thumbnail(album, @playlist_info[:thumbnail_url])
    end

    album
  end

  def import_tracks
    @items.each do |item|
      enriched = YoutubeMetadataEnricher.call(title: item[:title], channel_name: @playlist_info[:channel_name])

      track_artist = if enriched[:source] == :parsed
        @user.artists.find_or_create_by!(name: enriched[:artist]) { |a| a.category = @category }
      else
        @artist
      end

      @user.tracks.find_or_create_by!(youtube_video_id: item[:video_id]) do |track|
        track.title = enriched[:title]
        track.artist = track_artist
        track.album = @album
        track.track_number = item[:position] + 1
        track.duration = item[:duration]
      end
    end
  end

  def fetch_playlist_data
    if @api_key.present?
      fetch_playlist_data_via_api
    else
      fetch_playlist_data_via_ytdlp
    end
  end

  def fetch_playlist_data_via_api
    api = YoutubeAPIService.new(api_key: @api_key)

    playlist_info = api.fetch_playlist_info(@playlist_id)
    playlist_items = api.fetch_playlist_items(@playlist_id)

    video_ids = playlist_items.map { |item| item[:video_id] }
    video_details = api.fetch_video_details(video_ids)
    details_by_id = video_details.index_by { |v| v[:video_id] }

    items = playlist_items.map do |item|
      details = details_by_id[item[:video_id]] || {}
      {
        video_id: item[:video_id],
        title: item[:title],
        position: item[:position],
        duration: details[:duration]
      }
    end

    [playlist_info, items]
  end

  def fetch_playlist_data_via_ytdlp
    metadata = MediaDownloadService.fetch_playlist_metadata(@url)

    playlist_info = {
      title: metadata[:title],
      channel_name: metadata[:channel_name],
      thumbnail_url: metadata[:thumbnail_url]
    }

    [playlist_info, metadata[:entries]]
  end
end
