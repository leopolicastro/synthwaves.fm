class FilenameEpisodeParser
  Result = Data.define(:season_number, :episode_number, :title)

  PATTERNS = [
    # S01E03 or s01e03
    /S(\d{1,2})E(\d{1,3})/i,
    # 1x03
    /(\d{1,2})x(\d{1,3})/i
  ].freeze

  EPISODE_ONLY_PATTERNS = [
    # E03 or e03
    /\bE(\d{1,3})\b/i,
    # 03 - Title (leading number before separator)
    /\A(\d{1,3})\s*[-_.]\s*/
  ].freeze

  def self.parse(filename, default_season: nil)
    new(filename, default_season: default_season).parse
  end

  def initialize(filename, default_season: nil)
    @basename = File.basename(filename, File.extname(filename))
    @default_season = default_season
  end

  def parse
    # Try full season+episode patterns first
    PATTERNS.each do |pattern|
      if (match = @basename.match(pattern))
        title = extract_title(@basename, match)
        return Result.new(
          season_number: match[1].to_i,
          episode_number: match[2].to_i,
          title: title
        )
      end
    end

    # Try episode-only patterns
    EPISODE_ONLY_PATTERNS.each do |pattern|
      if (match = @basename.match(pattern))
        title = extract_title(@basename, match)
        return Result.new(
          season_number: @default_season,
          episode_number: match[1].to_i,
          title: title
        )
      end
    end

    # No pattern matched — no episode info
    Result.new(
      season_number: @default_season,
      episode_number: nil,
      title: @basename.strip
    )
  end

  private

  def extract_title(basename, match)
    # Remove the matched pattern and clean up separators
    remainder = basename.sub(match[0], "")
    remainder = remainder.gsub(/\A[\s\-_.]+|[\s\-_.]+\z/, "").strip
    remainder.presence
  end
end
