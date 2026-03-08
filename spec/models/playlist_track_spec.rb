require "rails_helper"

RSpec.describe PlaylistTrack, type: :model do
  describe "associations" do
    it { should belong_to(:playlist) }
    it { should belong_to(:track) }
  end
end
