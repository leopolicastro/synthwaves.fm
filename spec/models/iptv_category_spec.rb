require "rails_helper"

RSpec.describe IPTVCategory, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:iptv_channels).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:iptv_category) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe "slug generation" do
    it "generates slug from name when blank" do
      category = build(:iptv_category, name: "News & Sports", slug: nil)
      category.valid?
      expect(category.slug).to eq("news-sports")
    end

    it "does not overwrite an existing slug" do
      category = build(:iptv_category, name: "News", slug: "custom-slug")
      category.valid?
      expect(category.slug).to eq("custom-slug")
    end
  end

  describe ".with_channels" do
    it "returns only categories with channels" do
      with = create(:iptv_category, channels_count: 5)
      _without = create(:iptv_category, channels_count: 0)

      expect(described_class.with_channels).to eq([with])
    end
  end
end
