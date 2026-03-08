require "rails_helper"

RSpec.describe Album, type: :model do
  describe "associations" do
    it { should belong_to(:artist) }
    it { should have_many(:tracks).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
    it { should have_one_attached(:cover_image) }
  end

  describe "validations" do
    subject { build(:album) }

    it { should validate_presence_of(:title) }
    it { should validate_uniqueness_of(:title).scoped_to(:artist_id) }
  end
end
