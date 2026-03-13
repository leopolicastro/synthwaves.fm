require "rails_helper"

RSpec.describe VideoPlaybackPosition, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:video) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
  end

  describe "uniqueness" do
    it "enforces one position per user per video" do
      user = create(:user)
      video = create(:video, user: user)
      create(:video_playback_position, user: user, video: video, position: 10.0)

      duplicate = build(:video_playback_position, user: user, video: video, position: 20.0)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
