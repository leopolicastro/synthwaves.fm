module TracksHelper
  LANGUAGE_NAMES = {
    "en" => "English", "es" => "Spanish", "fr" => "French",
    "de" => "German", "pt" => "Portuguese", "it" => "Italian",
    "nl" => "Dutch", "sv" => "Swedish", "no" => "Norwegian",
    "da" => "Danish", "fi" => "Finnish", "pl" => "Polish",
    "ru" => "Russian", "ar" => "Arabic", "tr" => "Turkish",
    "hu" => "Hungarian", "cs" => "Czech", "ro" => "Romanian",
    "el" => "Greek", "ja" => "Japanese", "ko" => "Korean",
    "zh" => "Chinese", "th" => "Thai", "vi" => "Vietnamese",
    "id" => "Indonesian", "hi" => "Hindi", "fa" => "Farsi",
    "he" => "Hebrew", "nb" => "Norwegian"
  }.freeze

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

  def language_name(code)
    LANGUAGE_NAMES[code] || code.upcase
  end

  def decade_label(decade)
    "#{decade}s"
  end
end
