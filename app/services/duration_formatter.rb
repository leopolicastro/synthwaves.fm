class DurationFormatter
  # Clock-style: "3:45" or "1:03:45"
  def self.clock(seconds)
    return "0:00" if seconds.nil? || seconds <= 0
    minutes = (seconds / 60).floor
    secs = (seconds % 60).floor
    if minutes >= 60
      hours = (minutes / 60).floor
      minutes %= 60
      "#{hours}:#{format("%02d", minutes)}:#{format("%02d", secs)}"
    else
      "#{minutes}:#{format("%02d", secs)}"
    end
  end

  # Human-readable: "5h 30m"
  def self.human(seconds)
    return "0m" if seconds.nil? || seconds <= 0

    hours = (seconds / 3600).floor
    minutes = ((seconds % 3600) / 60).floor

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  # Human-readable with days: "3d 5h"
  def self.human_long(seconds)
    return "0m" if seconds.nil? || seconds <= 0

    days = (seconds / 86400).floor
    hours = ((seconds % 86400) / 3600).floor

    if days > 0
      "#{days}d #{hours}h"
    else
      human(seconds)
    end
  end
end
