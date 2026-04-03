class FilenameUtils
  def self.sanitize(name)
    name.to_s.gsub(/[^\w\s\-.]/, "").strip.gsub(/\s+/, " ")
  end
end
