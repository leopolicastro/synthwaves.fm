class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @genre = params[:genre].presence
    @year_from = params[:year_from].presence&.to_i
    @year_to = params[:year_to].presence&.to_i
    @favorites_only = params[:favorites_only] == "1"
    @genres = Album.distinct.pluck(:genre).compact.sort

    @results = if @query.present?
      SearchService.call(
        query: @query, genre: @genre, year_from: @year_from,
        year_to: @year_to, favorites_only: @favorites_only, user: Current.user
      )
    else
      {artists: [], albums: [], tracks: []}
    end

    @favorited_track_ids = Current.user.favorited_ids_for("Track")
  end

  def dropdown
    @query = params[:q].to_s.strip
    @results = if @query.present?
      SearchService.call(query: @query, limit: 5, user: Current.user)
    else
      {artists: [], albums: [], tracks: []}
    end
    render layout: false
  end
end
