require "rails_helper"

RSpec.describe UserRecording, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:recording) }
  end

  describe "validations" do
    it "prevents duplicate user-recording pairs" do
      user_recording = create(:user_recording)
      duplicate = build(:user_recording, user: user_recording.user, recording: user_recording.recording)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end
end
