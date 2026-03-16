module TracksHelper
  def format_duration(seconds)
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
end
