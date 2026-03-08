class PlaylistTrack < ApplicationRecord
  belongs_to :playlist, counter_cache: true
  belongs_to :track
end
