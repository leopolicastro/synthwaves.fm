require "rails_helper"

RSpec.describe API::V1::AlbumSerializer do
  let(:album) { create(:album) }

  describe ":full view" do
    it "returns all fields with nested artist" do
      result = described_class.render_as_hash(album, view: :full)
      expect(result).to include(:id, :title, :year, :genre, :artist, :tracks_count, :cover_image_url, :created_at)
      expect(result[:artist]).to include(:id, :name)
    end
  end

  describe ":summary view" do
    it "returns summary fields without artist" do
      result = described_class.render_as_hash(album, view: :summary)
      expect(result).to include(:id, :title, :year, :genre, :tracks_count, :cover_image_url)
      expect(result).not_to have_key(:artist)
    end
  end

  describe ":ref view" do
    it "returns id and title" do
      result = described_class.render_as_hash(album, view: :ref)
      expect(result).to include(:id, :title)
      expect(result).not_to have_key(:year)
    end
  end

  describe ":search_result view" do
    it "returns search fields with nested artist" do
      result = described_class.render_as_hash(album, view: :search_result)
      expect(result).to include(:id, :title, :year, :genre, :artist)
      expect(result[:artist]).to include(:id, :name)
    end
  end
end
