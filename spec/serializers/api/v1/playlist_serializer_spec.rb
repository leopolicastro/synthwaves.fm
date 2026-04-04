require "rails_helper"

RSpec.describe API::V1::PlaylistSerializer do
  let(:playlist) { create(:playlist) }

  describe ".to_full" do
    it "returns all fields" do
      result = described_class.to_full(playlist)
      expect(result).to include(:id, :name, :tracks_count, :created_at, :updated_at)
    end
  end

  describe ".to_ref" do
    it "returns id and name" do
      result = described_class.to_ref(playlist)
      expect(result.keys).to match_array([:id, :name])
    end
  end
end
