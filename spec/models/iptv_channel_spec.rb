require "rails_helper"

RSpec.describe IPTVChannel, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:iptv_category).optional }
  end

  describe "validations" do
    subject { build(:iptv_channel) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:stream_url) }
    it { is_expected.to validate_uniqueness_of(:tvg_id) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active channels" do
        active = create(:iptv_channel, active: true)
        _inactive = create(:iptv_channel, active: false)

        expect(described_class.active).to eq([active])
      end
    end

    describe ".by_country" do
      it "filters by country" do
        us = create(:iptv_channel, country: "US")
        _uk = create(:iptv_channel, country: "UK")

        expect(described_class.by_country("US")).to eq([us])
      end

      it "returns all when country is blank" do
        create(:iptv_channel, country: "US")
        create(:iptv_channel, country: "UK")

        expect(described_class.by_country(nil).count).to eq(2)
      end
    end

    describe ".by_language" do
      it "filters by language" do
        en = create(:iptv_channel, language: "English")
        _es = create(:iptv_channel, language: "Spanish")

        expect(described_class.by_language("English")).to eq([en])
      end
    end

    describe ".search" do
      it "searches by name" do
        cnn = create(:iptv_channel, name: "CNN International")
        _bbc = create(:iptv_channel, name: "BBC World")

        expect(described_class.search("CNN")).to eq([cnn])
      end

      it "returns all when query is blank" do
        create(:iptv_channel)
        expect(described_class.search(nil).count).to eq(1)
      end
    end
  end

  describe "counter_cache" do
    it "updates category channels_count" do
      category = create(:iptv_category)
      expect { create(:iptv_channel, iptv_category: category) }
        .to change { category.reload.channels_count }.from(0).to(1)
    end
  end
end
