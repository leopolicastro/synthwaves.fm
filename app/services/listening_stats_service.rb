class ListeningStatsService
  RANGES = {
    week: 7.days,
    month: 30.days,
    year: 365.days,
    all_time: nil
  }.freeze

  def self.call(user:, time_range: :month)
    new(user: user, time_range: time_range).call
  end

  def initialize(user:, time_range:)
    @user = user
    @time_range = time_range.to_sym
  end

  def call
    {
      top_tracks: top_tracks,
      top_artists: top_artists,
      top_genres: top_genres,
      total_plays: total_plays,
      total_listening_time: total_listening_time,
      current_streak: calculate_streak(:current),
      longest_streak: calculate_streak(:longest),
      hourly_distribution: hourly_distribution,
      daily_distribution: daily_distribution
    }
  end

  private

  def base_scope
    scope = @user.play_histories.joins(track: [:artist, :album])
    if (duration = RANGES[@time_range])
      scope = scope.where("play_histories.played_at >= ?", duration.ago)
    end
    scope
  end

  def top_tracks(limit: 10)
    base_scope
      .select("tracks.id, tracks.title, artists.name AS artist_name, COUNT(*) AS play_count")
      .group("tracks.id, tracks.title, artists.name")
      .order("play_count DESC")
      .limit(limit)
  end

  def top_artists(limit: 10)
    base_scope
      .select("artists.id, artists.name, COUNT(*) AS play_count")
      .group("artists.id, artists.name")
      .order("play_count DESC")
      .limit(limit)
  end

  def top_genres(limit: 10)
    base_scope
      .where("albums.genre IS NOT NULL AND albums.genre != ''")
      .select("albums.genre, COUNT(*) AS play_count")
      .group("albums.genre")
      .order("play_count DESC")
      .limit(limit)
  end

  def total_plays
    base_scope.count
  end

  def total_listening_time
    base_scope
      .sum("tracks.duration")
      .to_f
  end

  def hourly_distribution
    result = Array.new(24, 0)
    base_scope
      .select("strftime('%H', play_histories.played_at) AS hour, COUNT(*) AS play_count")
      .group("hour")
      .each { |r| result[r.hour.to_i] = r.play_count }
    result
  end

  def daily_distribution
    result = Array.new(7, 0)
    base_scope
      .select("strftime('%w', play_histories.played_at) AS dow, COUNT(*) AS play_count")
      .group("dow")
      .each { |r| result[r.dow.to_i] = r.play_count }
    result
  end

  def calculate_streak(type)
    dates = listening_dates
    return 0 if dates.empty?

    (type == :current) ? current_streak(dates) : longest_streak(dates)
  end

  def listening_dates
    @user.play_histories
      .select("DATE(played_at) AS play_date")
      .distinct
      .order("play_date DESC")
      .map { |r| r.play_date.to_date }
  end

  def current_streak(dates)
    streak = 0
    expected = Date.current
    dates.each do |d|
      if d == expected
        streak += 1
        expected -= 1.day
      elsif d == expected - 1.day
        expected = d
        streak += 1
        expected -= 1.day
      else
        break
      end
    end
    streak
  end

  def longest_streak(dates)
    max_streak = 1
    current = 1
    dates.each_cons(2) do |a, b|
      if (a - b).to_i == 1
        current += 1
        max_streak = [max_streak, current].max
      else
        current = 1
      end
    end
    max_streak
  end
end
