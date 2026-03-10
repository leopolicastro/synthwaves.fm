class StatsController < ApplicationController
  def show
    @time_range = (params[:range] || "month").to_sym
    @time_range = :month unless ListeningStatsService::RANGES.key?(@time_range)
    @stats = ListeningStatsService.call(user: Current.user, time_range: @time_range)
  end
end
