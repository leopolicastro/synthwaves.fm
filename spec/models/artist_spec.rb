require "rails_helper"

RSpec.describe Artist, type: :model do
  describe "associations" do
    it { should have_many(:albums).dependent(:destroy) }
    it { should have_many(:tracks).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:artist) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
  end
end
