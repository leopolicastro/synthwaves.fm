class RadioQueueTrack < ApplicationRecord
  belongs_to :radio_station
  belongs_to :track

  scope :upcoming, -> { where(played_at: nil).order(:position) }
  scope :played, -> { where.not(played_at: nil).order(played_at: :desc) }
  scope :recently_played, ->(limit = 10) { played.limit(limit) }
end
