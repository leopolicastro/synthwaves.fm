class YoutubePlaylistImportService
  include ThumbnailAttachable

  class Error < StandardError; end

  def self.call(url, category: "music", api_key:)
    new(url, category: category, api_key: api_key).call
  end

  def initialize(url, category: "music", api_key:)
    @url = url
    @category = category
    @api_key = api_key
    @playlist_id = YoutubeUrlParser.extract_playlist_id(url)
    raise Error, "Invalid YouTube playlist URL" if @playlist_id.blank?
  end

  def call
    api = YoutubeAPIService.new(api_key: @api_key)

    playlist_info = api.fetch_playlist_info(@playlist_id)
    playlist_items = api.fetch_playlist_items(@playlist_id)

    return nil if playlist_items.empty?

    video_ids = playlist_items.map { |item| item[:video_id] }
    video_details = api.fetch_video_details(video_ids)
    details_by_id = video_details.index_by { |v| v[:video_id] }

    artist = Artist.find_or_create_by!(name: playlist_info[:channel_name] || "Unknown Artist") do |a|
      a.category = @category
    end

    album = Album.find_or_create_by!(title: playlist_info[:title], artist: artist)
    album.update!(youtube_playlist_url: @url) if album.youtube_playlist_url.blank?

    if playlist_info[:thumbnail_url].present? && !album.cover_image.attached?
      attach_thumbnail(album, playlist_info[:thumbnail_url])
    end

    playlist_items.each do |item|
      details = details_by_id[item[:video_id]] || {}

      Track.find_or_create_by!(youtube_video_id: item[:video_id]) do |track|
        track.title = item[:title]
        track.artist = artist
        track.album = album
        track.track_number = item[:position] + 1
        track.duration = details[:duration]
      end
    end

    album
  end

  private

end
