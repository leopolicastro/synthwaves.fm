class VideoPlaybackPosition < ApplicationRecord
  belongs_to :user
  belongs_to :video

  validates :position, numericality: {greater_than_or_equal_to: 0}
end
