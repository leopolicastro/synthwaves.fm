class APIKeyResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :client_id
  attribute :expires_at
  attribute :last_used_at
  attribute :last_used_ip
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :secret_key, index: false, show: false
  attribute :secret_key_confirmation, index: false, show: false

  # Associations
  attribute :user

  # Add scopes to easily filter records
  # scope :published

  # Add actions to the resource's show page
  # member_action do |record|
  #   link_to "Do Something", some_path
  # end

  # Customize the display name of records in the admin area.
  # def self.display_name(record) = record.name

  # Customize the default sort column and direction.
  # def self.default_sort_column = "created_at"
  #
  # def self.default_sort_direction = "desc"
end
