class API::V1::SearchController < API::V1::BaseController
  def index
    unless params[:q].present?
      return render_error("q parameter required")
    end

    types = if params[:types].present?
      params[:types].split(",").map(&:strip).map(&:to_sym) & [:artist, :album, :track]
    else
      [:artist, :album, :track]
    end

    results = SearchService.call(
      query: params[:q],
      types: types,
      limit: [(params[:limit] || 20).to_i, 50].min,
      genre: params[:genre],
      year_from: params[:year_from]&.to_i,
      year_to: params[:year_to]&.to_i,
      favorites_only: params[:favorites_only] == "1",
      user: current_user
    )

    render json: {
      artists: results[:artists].map { |a| {id: a.id, name: a.name, category: a.category} },
      albums: results[:albums].map { |a| {id: a.id, title: a.title, year: a.year, genre: a.genre, artist: {id: a.artist_id, name: a.artist.name}} },
      tracks: results[:tracks].map { |t| {id: t.id, title: t.title, duration: t.duration, artist: {id: t.artist_id, name: t.artist.name}, album: {id: t.album_id, title: t.album.title}} }
    }
  end
end
