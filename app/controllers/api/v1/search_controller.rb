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
      category: params[:category].presence,
      tags: params[:tags]&.split(",")&.map(&:strip),
      user: current_user
    )

    render json: {
      artists: results[:artists].map { |a| API::V1::ArtistSerializer.to_summary(a) },
      albums: results[:albums].map { |a| API::V1::AlbumSerializer.to_search_result(a) },
      tracks: results[:tracks].map { |t| API::V1::TrackSerializer.to_embedded(t) }
    }
  end
end
