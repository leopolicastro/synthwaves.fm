require "rails_helper"

RSpec.describe API::V1::AlbumSerializer do
  let(:album) { create(:album) }

  describe ".to_full" do
    it "returns all fields with nested artist" do
      result = described_class.to_full(album)
      expect(result).to include(:id, :title, :year, :genre, :artist, :tracks_count, :cover_image_url, :created_at)
      expect(result[:artist]).to include(:id, :name)
    end
  end

  describe ".to_summary" do
    it "returns summary fields without artist" do
      result = described_class.to_summary(album)
      expect(result).to include(:id, :title, :year, :genre, :tracks_count, :cover_image_url)
      expect(result).not_to have_key(:artist)
    end
  end

  describe ".to_ref" do
    it "returns id and title" do
      result = described_class.to_ref(album)
      expect(result.keys).to match_array([:id, :title])
    end
  end

  describe ".to_search_result" do
    it "returns search fields with nested artist" do
      result = described_class.to_search_result(album)
      expect(result).to include(:id, :title, :year, :genre, :artist)
      expect(result[:artist]).to include(:id, :name)
    end
  end
end
