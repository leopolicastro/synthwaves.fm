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

  def format_library_duration(seconds)
    return "0m" if seconds.nil? || seconds <= 0

    days = (seconds / 86400).floor
    hours = ((seconds % 86400) / 3600).floor

    if days > 0
      "#{days}d #{hours}h"
    else
      format_listening_time(seconds)
    end
  end
end
