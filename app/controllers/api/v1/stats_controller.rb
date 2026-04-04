class API::V1::StatsController < API::V1::BaseController
  def show
    time_range = params[:time_range]&.to_sym || :month

    unless ListeningStatsService::RANGES.key?(time_range)
      return render_error("time_range must be one of: #{ListeningStatsService::RANGES.keys.join(", ")}")
    end

    library = LibraryStatsService.call(user: current_user)
    listening = ListeningStatsService.call(user: current_user, time_range: time_range)

    render json: {
      library: library,
      listening: {
        time_range: time_range,
        total_plays: listening[:total_plays],
        total_listening_time: listening[:total_listening_time],
        current_streak: listening[:current_streak],
        longest_streak: listening[:longest_streak],
        top_tracks: listening[:top_tracks].map { |t| {id: t.id, title: t.title, artist_name: t.artist_name, play_count: t.play_count} },
        top_artists: listening[:top_artists].map { |a| {id: a.id, name: a.name, play_count: a.play_count} },
        top_genres: listening[:top_genres].map { |g| {genre: g.genre, play_count: g.play_count} },
        hourly_distribution: listening[:hourly_distribution],
        daily_distribution: listening[:daily_distribution]
      }
    }
  end
end
