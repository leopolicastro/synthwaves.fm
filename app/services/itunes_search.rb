class ItunesSearch
  SEARCH_URL = "https://itunes.apple.com/search"

  def self.call(artist:, title:)
    return nil if artist.blank? && title.blank?

    term = [artist, title].compact.join(" ")
    response = HTTP.get(SEARCH_URL, params: {
      term: term,
      media: "music",
      entity: "song",
      limit: 5
    })

    return nil unless response.status.success?

    results = JSON.parse(response.body.to_s)["results"]
    return nil if results.blank?

    best = pick_best_match(results, artist: artist, title: title)
    return nil unless best

    artwork_url = best["artworkUrl100"]&.sub("100x100", "600x600")

    {
      artist: best["artistName"],
      album: best["collectionName"],
      title: best["trackName"],
      track_number: best["trackNumber"],
      disc_number: best["discNumber"],
      genre: best["primaryGenreName"],
      year: parse_year(best["releaseDate"]),
      artwork_url: artwork_url
    }
  end

  def self.pick_best_match(results, artist:, title:)
    results.min_by do |r|
      score = 0
      score += levenshtein(r["trackName"]&.downcase || "", (title || "").downcase)
      score += levenshtein(r["artistName"]&.downcase || "", (artist || "").downcase)
      score
    end
  end

  def self.parse_year(release_date)
    return nil unless release_date
    Date.parse(release_date).year
  rescue Date::Error
    nil
  end

  def self.levenshtein(a, b)
    return b.length if a.empty?
    return a.length if b.empty?

    matrix = Array.new(a.length + 1) { |i| i }
    (1..b.length).each do |j|
      prev = matrix[0]
      matrix[0] = j
      (1..a.length).each do |i|
        temp = matrix[i]
        matrix[i] = if a[i - 1] == b[j - 1]
          prev
        else
          [prev, matrix[i], matrix[i - 1]].min + 1
        end
        prev = temp
      end
    end
    matrix[a.length]
  end

  private_class_method :pick_best_match, :parse_year, :levenshtein
end
