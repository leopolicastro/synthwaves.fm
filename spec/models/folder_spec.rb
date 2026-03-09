require "rails_helper"

RSpec.describe Folder, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:videos).dependent(:nullify) }
    it { should have_one_attached(:cover_image) }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    subject { create(:folder) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  describe ".search" do
    it "returns folders matching by name" do
      matching = create(:folder, name: "Season One")
      non_matching = create(:folder, name: "Movies")

      results = Folder.search("Season")

      expect(results).to include(matching)
      expect(results).not_to include(non_matching)
    end

    it "returns all folders when query is blank" do
      folders = create_list(:folder, 3)
      expect(Folder.search("")).to match_array(folders)
    end

    it "returns all folders when query is nil" do
      folders = create_list(:folder, 3)
      expect(Folder.search(nil)).to match_array(folders)
    end
  end
end
