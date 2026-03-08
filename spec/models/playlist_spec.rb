require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:playlist_tracks).dependent(:destroy) }
    it { should have_many(:tracks).through(:playlist_tracks) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end
end
