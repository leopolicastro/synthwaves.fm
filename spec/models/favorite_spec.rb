require "rails_helper"

RSpec.describe Favorite, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:favorable) }
  end

  describe "validations" do
    it { should validate_inclusion_of(:favorable_type).in_array(%w[Track Album Artist IPTVChannel InternetRadioStation]) }
  end
end
