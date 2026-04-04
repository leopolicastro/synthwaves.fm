require "rails_helper"

RSpec.describe API::V1::ArtistSerializer do
  let(:artist) { create(:artist) }

  describe ".to_full" do
    it "returns all fields" do
      result = described_class.to_full(artist)
      expect(result).to include(:id, :name, :category, :image_url, :albums_count, :tracks_count, :created_at)
      expect(result[:name]).to eq(artist.name)
    end
  end

  describe ".to_summary" do
    it "returns id, name, and category" do
      result = described_class.to_summary(artist)
      expect(result.keys).to match_array([:id, :name, :category])
    end
  end

  describe ".to_ref" do
    it "returns id and name" do
      result = described_class.to_ref(artist)
      expect(result.keys).to match_array([:id, :name])
    end
  end
end
