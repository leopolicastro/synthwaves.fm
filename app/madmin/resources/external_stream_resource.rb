class ExternalStreamResource < Madmin::Resource
  attribute :id, form: false
  attribute :name
  attribute :user
  attribute :source_type
  attribute :youtube_url, index: false
  attribute :youtube_video_id
  attribute :stream_url, index: false
  attribute :original_url, index: false
  attribute :thumbnail_url, index: false
  attribute :description, index: false
  attribute :created_at, form: false, index: false
  attribute :updated_at, form: false, index: false

  def self.display_name(record) = record.name
  def self.default_sort_column = "name"
end
