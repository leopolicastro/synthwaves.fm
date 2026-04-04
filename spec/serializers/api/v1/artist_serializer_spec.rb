require "rails_helper"

RSpec.describe API::V1::ArtistSerializer do
  let(:artist) { create(:artist) }

  describe ":full view" do
    it "returns all fields" do
      result = described_class.render_as_hash(artist, view: :full)
      expect(result).to include(:id, :name, :category, :image_url, :albums_count, :tracks_count, :created_at)
      expect(result[:name]).to eq(artist.name)
    end
  end

  describe ":summary view" do
    it "returns id, name, and category" do
      result = described_class.render_as_hash(artist, view: :summary)
      expect(result).to include(:id, :name, :category)
      expect(result).not_to have_key(:image_url)
    end
  end

  describe ":ref view" do
    it "returns id and name" do
      result = described_class.render_as_hash(artist, view: :ref)
      expect(result).to include(:id, :name)
      expect(result).not_to have_key(:category)
    end
  end

  describe "collection rendering" do
    it "renders a collection" do
      artists = create_list(:artist, 2)
      result = described_class.render_as_hash(artists, view: :full)
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end
  end
end
