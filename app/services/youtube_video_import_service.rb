class YoutubeVideoImportService
  include ThumbnailAttachable

  class Error < StandardError; end

  SINGLES_ALBUM_TITLE = "YouTube Singles"

  def self.call(url, category: "music", api_key:)
    new(url, category: category, api_key: api_key).call
  end

  def initialize(url, category: "music", api_key:)
    @url = url
    @category = category
    @api_key = api_key
    @video_id = YoutubeUrlParser.extract_video_id(url)
    raise Error, "Invalid YouTube video URL" if @video_id.blank?
  end

  def call
    existing_track = Track.find_by(youtube_video_id: @video_id)
    return existing_track if existing_track

    api = YoutubeAPIService.new(api_key: @api_key)
    details = api.fetch_video_details([@video_id]).first
    raise Error, "Video not found" if details.nil?

    artist = Artist.find_or_create_by!(name: details[:channel_name] || "Unknown Artist") do |a|
      a.category = @category
    end

    album = Album.find_or_create_by!(title: SINGLES_ALBUM_TITLE, artist: artist)

    if details[:thumbnail_url].present? && !album.cover_image.attached?
      attach_thumbnail(album, details[:thumbnail_url])
    end

    next_track_number = (album.tracks.maximum(:track_number) || 0) + 1

    Track.create!(
      title: details[:title],
      artist: artist,
      album: album,
      youtube_video_id: @video_id,
      duration: details[:duration],
      track_number: next_track_number
    )
  end

  private

end
