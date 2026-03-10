module StatsHelper
  def format_listening_time(seconds)
    return "0m" if seconds.nil? || seconds <= 0

    hours = (seconds / 3600).floor
    minutes = ((seconds % 3600) / 60).floor

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end
end
