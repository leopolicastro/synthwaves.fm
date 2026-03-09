class UserRecording < ApplicationRecord
  belongs_to :user
  belongs_to :recording

  validates :user_id, uniqueness: {scope: :recording_id}
end
