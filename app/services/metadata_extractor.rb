class MetadataExtractor
  def self.call(file_path)
    new(file_path).call
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    tag = WahWah.open(@file_path)

    {
      title: tag.title.presence,
      artist: tag.artist.presence,
      album: tag.album.presence,
      year: parse_year(tag.year),
      genre: tag.genre.presence,
      track_number: parse_int(tag.track),
      disc_number: parse_int(tag.disc),
      duration: tag.duration&.to_f,
      bitrate: tag.bitrate&.to_i,
      cover_art: extract_cover_art(tag)
    }
  end

  private

  def parse_year(value)
    return nil if value.blank?
    value.to_s[/\d{4}/]&.to_i
  end

  def parse_int(value)
    return nil if value.blank?
    value.to_s.split("/").first&.to_i
  end

  def extract_cover_art(tag)
    images = tag.images
    return nil if images.blank?

    image = images.first
    {
      data: image[:data],
      mime_type: image[:media_type]
    }
  end
end
