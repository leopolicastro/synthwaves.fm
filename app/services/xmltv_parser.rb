class XMLTVParser
  ProgrammeEntry = Data.define(:channel_id, :title, :subtitle, :description, :starts_at, :ends_at)

  def self.parse(xml_content)
    new(xml_content).parse
  end

  def initialize(xml_content)
    @xml_content = xml_content
  end

  def parse
    doc = Nokogiri::XML(@xml_content)

    doc.xpath("//programme").filter_map do |node|
      parse_programme(node)
    end
  end

  private

  def parse_programme(node)
    channel_id = node["channel"]
    title = node.at_xpath("title")&.text&.strip
    return unless channel_id.present? && title.present?

    starts_at = parse_xmltv_time(node["start"])
    ends_at = parse_xmltv_time(node["stop"])
    return unless starts_at && ends_at

    ProgrammeEntry.new(
      channel_id: channel_id,
      title: title,
      subtitle: node.at_xpath("sub-title")&.text&.strip,
      description: node.at_xpath("desc")&.text&.strip,
      starts_at: starts_at,
      ends_at: ends_at
    )
  end

  def parse_xmltv_time(time_str)
    return nil if time_str.blank?

    Time.strptime(time_str, "%Y%m%d%H%M%S %z")
  rescue ArgumentError
    nil
  end
end
