require "rails_helper"

RSpec.describe PlayHistory, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:track) }
  end
end
