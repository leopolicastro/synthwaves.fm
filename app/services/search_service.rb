class SearchService
  def self.call(query:, types: [:artist, :album, :track], limit: 20)
    new(query: query, types: types, limit: limit).call
  end

  def initialize(query:, types:, limit:)
    @query = query
    @types = types
    @limit = limit
  end

  def call
    pattern = "%#{@query}%"
    {
      artists: search_artists(pattern),
      albums: search_albums(pattern),
      tracks: search_tracks(pattern)
    }
  end

  private

  def search_artists(pattern)
    return [] unless @types.include?(:artist)
    Artist.where("name LIKE ?", pattern).limit(@limit)
  end

  def search_albums(pattern)
    return [] unless @types.include?(:album)
    Album.includes(:artist).where("title LIKE ?", pattern).limit(@limit)
  end

  def search_tracks(pattern)
    return [] unless @types.include?(:track)
    Track.includes(:artist, :album).where("title LIKE ?", pattern).limit(@limit)
  end
end
