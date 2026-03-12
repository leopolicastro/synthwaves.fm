require "rails_helper"

RSpec.describe ApplicationRecord, type: :model do
  describe ".sort_by_params" do
    it "sorts by a valid column" do
      artist_b = create(:artist, name: "Bravo")
      artist_a = create(:artist, name: "Alpha")

      result = Artist.sort_by_params("name", "asc")
      expect(result.first).to eq(artist_a)
      expect(result.last).to eq(artist_b)
    end

    it "respects descending direction" do
      artist_b = create(:artist, name: "Bravo")
      artist_a = create(:artist, name: "Alpha")

      result = Artist.sort_by_params("name", "desc")
      expect(result.first).to eq(artist_b)
      expect(result.last).to eq(artist_a)
    end

    it "falls back to created_at for invalid column names" do
      artist_first = create(:artist, name: "First")
      artist_second = create(:artist, name: "Second")

      result = Artist.sort_by_params("DROP TABLE artists", "asc")
      expect(result.to_a).to eq([artist_first, artist_second])
    end

    it "falls back to created_at for blank column" do
      create(:artist, name: "Test")

      result = Artist.sort_by_params("", "asc")
      expect(result.to_a).not_to be_empty
    end

    it "falls back to created_at for nil column" do
      create(:artist, name: "Test")

      result = Artist.sort_by_params(nil, "asc")
      expect(result.to_a).not_to be_empty
    end
  end

  describe ".sortable_columns" do
    it "returns column names from the table" do
      columns = Artist.sortable_columns
      expect(columns).to include("name")
      expect(columns).to include("created_at")
    end

    it "does not include arbitrary strings" do
      columns = Artist.sortable_columns
      expect(columns).not_to include("malicious_column")
    end
  end
end
