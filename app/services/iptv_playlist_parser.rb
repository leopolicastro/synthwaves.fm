class IPTVPlaylistParser
  ChannelEntry = Data.define(:tvg_id, :name, :logo_url, :group_title, :country, :language, :stream_url)

  def self.parse(content)
    new(content).parse
  end

  def initialize(content)
    @content = content
  end

  def parse
    entries = []
    current_metadata = {}

    @content.each_line do |line|
      line = line.strip
      next if line.empty?

      if line.start_with?("#EXTINF:")
        current_metadata = parse_extinf(line)
      elsif !line.start_with?("#")
        entries << build_entry(current_metadata, line)
        current_metadata = {}
      end
    end

    entries
  end

  private

  def parse_extinf(line)
    metadata = {}

    metadata[:tvg_id] = extract_attribute(line, "tvg-id")
    metadata[:logo_url] = extract_attribute(line, "tvg-logo")
    metadata[:group_title] = extract_attribute(line, "group-title")
    metadata[:country] = extract_attribute(line, "tvg-country")
    metadata[:language] = extract_attribute(line, "tvg-language")

    # Channel name is after the last comma
    if (match = line.match(/,(.+)\z/))
      metadata[:name] = match[1].strip
    end

    metadata
  end

  def extract_attribute(line, attr_name)
    if (match = line.match(/#{attr_name}="([^"]*)"/i))
      value = match[1].strip
      value.presence
    end
  end

  def build_entry(metadata, stream_url)
    ChannelEntry.new(
      tvg_id: metadata[:tvg_id],
      name: metadata[:name] || "Unknown",
      logo_url: metadata[:logo_url],
      group_title: metadata[:group_title],
      country: metadata[:country],
      language: metadata[:language],
      stream_url: stream_url
    )
  end
end
