module StatsHelper
  def format_listening_time(seconds)
    DurationFormatter.human(seconds)
  end

  def format_library_duration(seconds)
    DurationFormatter.human_long(seconds)
  end
end
