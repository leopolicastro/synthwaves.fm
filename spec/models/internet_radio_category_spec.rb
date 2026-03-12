require "rails_helper"

RSpec.describe InternetRadioCategory, type: :model do
  describe "validations" do
    subject { build(:internet_radio_category) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_uniqueness_of(:slug) }
  end

  describe "associations" do
    it { should have_many(:internet_radio_stations).dependent(:nullify) }
  end

  describe "slug generation" do
    it "generates a slug from the name when blank" do
      category = InternetRadioCategory.create!(name: "Classic Rock")
      expect(category.slug).to eq("classic-rock")
    end

    it "does not overwrite an existing slug" do
      category = InternetRadioCategory.create!(name: "Classic Rock", slug: "custom-slug")
      expect(category.slug).to eq("custom-slug")
    end

    it "handles unicode characters in names" do
      category = InternetRadioCategory.create!(name: "Musique Fran\u00E7aise")
      expect(category.slug).to be_present
      expect(category.slug).not_to include(" ")
    end
  end

  describe ".with_stations" do
    it "returns categories with stations_count > 0" do
      with_stations = create(:internet_radio_category, stations_count: 3)
      without_stations = create(:internet_radio_category, stations_count: 0)

      result = described_class.with_stations
      expect(result).to include(with_stations)
      expect(result).not_to include(without_stations)
    end
  end
end
