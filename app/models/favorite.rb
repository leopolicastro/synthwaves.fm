class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favorable, polymorphic: true

  validates :favorable_type, inclusion: {in: %w[Track Album Artist IPTVChannel InternetRadioStation Video Folder]}
end
