class CoverArtSearchService
  def self.call(album)
    new(album).call
  end

  def initialize(album)
    @album = album
  end

  def call
    try_audio_metadata || try_youtube_thumbnail || try_cover_art_archive || try_itunes_search || :not_found
  end

  private

  def try_audio_metadata
    @album.tracks.each do |track|
      next unless track.audio_file.attached?

      track.audio_file.open do |tempfile|
        metadata = MetadataExtractor.call(tempfile.path)
        next unless metadata[:cover_art]

        @album.cover_image.attach(
          io: StringIO.new(metadata[:cover_art][:data]),
          filename: "cover.jpg",
          content_type: metadata[:cover_art][:mime_type] || "image/jpeg"
        )
        return :audio
      end
    end

    nil
  end

  def try_youtube_thumbnail
    track = @album.tracks.find { |t| t.youtube_video_id.present? }
    return nil unless track

    thumbnail_url = "https://img.youtube.com/vi/#{track.youtube_video_id}/hqdefault.jpg"
    response = HTTP.get(thumbnail_url)
    return nil unless response.status.success?

    content_type = response.content_type.mime_type
    extension = case content_type
    when "image/png" then "png"
    when "image/webp" then "webp"
    else "jpg"
    end

    @album.cover_image.attach(
      io: StringIO.new(response.body.to_s),
      filename: "cover.#{extension}",
      content_type: content_type
    )
    :youtube
  rescue HTTP::Error
    nil
  end

  def try_cover_art_archive
    return nil unless @album.musicbrainz_release_id.present?

    url = "https://coverartarchive.org/release/#{@album.musicbrainz_release_id}/front-500"
    response = HTTP.get(url)
    return nil unless response.status.success?

    content_type = response.content_type&.mime_type || "image/jpeg"
    extension = case content_type
    when "image/png" then "png"
    when "image/webp" then "webp"
    else "jpg"
    end

    @album.cover_image.attach(
      io: StringIO.new(response.body.to_s),
      filename: "cover.#{extension}",
      content_type: content_type
    )
    :cover_art_archive
  rescue HTTP::Error
    nil
  end

  def try_itunes_search
    term = "#{@album.artist.name} #{@album.title}"
    response = HTTP.get("https://itunes.apple.com/search", params: {term: term, entity: "album", limit: 1})
    return nil unless response.status.success?

    results = JSON.parse(response.body.to_s)
    artwork_url = results.dig("results", 0, "artworkUrl100")
    return nil unless artwork_url

    hq_url = artwork_url.gsub("100x100bb", "600x600bb")
    image_response = HTTP.get(hq_url)
    return nil unless image_response.status.success?

    @album.cover_image.attach(
      io: StringIO.new(image_response.body.to_s),
      filename: "cover.jpg",
      content_type: image_response.content_type.mime_type
    )
    :itunes
  rescue HTTP::Error, JSON::ParserError
    nil
  end
end
