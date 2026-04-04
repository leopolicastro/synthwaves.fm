require "rails_helper"

RSpec.describe API::V1::PlaylistSerializer do
  let(:playlist) { create(:playlist) }

  describe ":full view" do
    it "returns all fields" do
      result = described_class.render_as_hash(playlist, view: :full)
      expect(result).to include(:id, :name, :tracks_count, :created_at, :updated_at)
    end
  end

  describe ":ref view" do
    it "returns id and name" do
      result = described_class.render_as_hash(playlist, view: :ref)
      expect(result).to include(:id, :name)
      expect(result).not_to have_key(:tracks_count)
    end
  end
end
