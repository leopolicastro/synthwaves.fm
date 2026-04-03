class DiscographyMergeService
  def self.call(artist, owned_albums, discography)
    new(artist, owned_albums, discography).call
  end

  def initialize(artist, owned_albums, discography)
    @artist = artist
    @owned_albums = owned_albums
    @discography = discography
  end

  def call
    matched_mbids = Set.new
    entries = []

    @owned_albums.each do |album|
      match = find_match(album)
      matched_mbids << match[:mbid] if match
      entries << {type: :owned, album: album, year: album.year}
    end

    @discography.each do |rg|
      next if matched_mbids.include?(rg[:mbid])

      entries << {
        type: :missing,
        title: rg[:title],
        year: rg[:year],
        mbid: rg[:mbid],
        cover_art_url: rg[:cover_art_url]
      }
    end

    entries.sort_by { |e| [e[:year] || 9999, (e[:type] == :owned) ? e[:album].title : e[:title]] }
  end

  private

  def find_match(album)
    @discography.find do |rg|
      match_by_release_id?(album, rg) || match_by_title?(album, rg)
    end
  end

  def match_by_release_id?(album, rg)
    album.musicbrainz_release_id.present? &&
      rg[:mbid].present? &&
      album.musicbrainz_release_id == rg[:mbid]
  end

  def match_by_title?(album, rg)
    owned = normalize(album.title)
    mb = normalize(rg[:title])

    return true if owned == mb
    return true if owned.include?(mb) || mb.include?(owned)

    owned_words = owned.split.to_set
    mb_words = mb.split.to_set
    overlap = (owned_words & mb_words).size
    smaller = [owned_words.size, mb_words.size].min
    smaller > 0 && overlap.to_f / smaller >= 0.7
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^\p{L}\p{N}\s]/, "").gsub(/\s+/, " ").strip
  end
end
