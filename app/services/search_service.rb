class SearchService
  DEFAULTS = {types: [:artist, :album, :track], limit: 20, category: "music"}.freeze

  def self.call(**options)
    new(**options).call
  end

  def initialize(query:, types: DEFAULTS[:types], limit: DEFAULTS[:limit],
    genre: nil, year_from: nil, year_to: nil,
    favorites_only: false, user: nil, category: DEFAULTS[:category], tags: nil)
    @query = query
    @types = types
    @limit = limit
    @genre = genre
    @year_from = year_from
    @year_to = year_to
    @favorites_only = favorites_only
    @user = user
    @category = category
    @tags = tags
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
    scope = base_scope(Artist).where("name LIKE ?", pattern)
    scope = scope.where(category: @category) if @category.present?
    scope = scope.where(id: @user.favorites.where(favorable_type: "Artist").select(:favorable_id)) if @favorites_only && @user
    scope.limit(@limit)
  end

  def search_albums(pattern)
    return [] unless @types.include?(:album)
    scope = base_scope(Album).includes(:artist).where("albums.title LIKE ?", pattern)
    scope = scope.joins(:artist).where(artists: {category: @category}) if @category.present?
    scope = scope.where(genre: @genre) if @genre.present?
    scope = scope.where("year >= ?", @year_from) if @year_from
    scope = scope.where("year <= ?", @year_to) if @year_to
    scope = scope.where(id: @user.favorites.where(favorable_type: "Album").select(:favorable_id)) if @favorites_only && @user
    scope.limit(@limit)
  end

  def search_tracks(pattern)
    return [] unless @types.include?(:track)
    scope = base_scope(Track).includes(:artist, :album).where("tracks.title LIKE ?", pattern)
    scope = scope.joins(:artist).where(artists: {category: @category}) if @category.present?
    if @genre.present? || @year_from || @year_to
      scope = scope.joins(:album)
      scope = scope.where(albums: {genre: @genre}) if @genre.present?
      scope = scope.where("albums.year >= ?", @year_from) if @year_from
      scope = scope.where("albums.year <= ?", @year_to) if @year_to
    end
    scope = scope.where(id: @user.favorites.where(favorable_type: "Track").select(:favorable_id)) if @favorites_only && @user
    scope = filter_by_tags(scope, "Track") if @tags.present?
    scope.limit(@limit)
  end

  def base_scope(model)
    @user ? @user.public_send(model.table_name) : model
  end

  def filter_by_tags(scope, taggable_type)
    tag_names = Array(@tags).map(&:downcase)
    scope.where(
      id: Tagging.joins(:tag)
        .where(taggable_type: taggable_type, tags: {name: tag_names})
        .select(:taggable_id)
    )
  end
end
