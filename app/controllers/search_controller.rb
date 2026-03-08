class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    if @query.present?
      @results = SearchService.call(query: @query)
    else
      @results = {artists: [], albums: [], tracks: []}
    end
  end
end
