require "rails_helper"

RSpec.describe API::V1::TrackSerializer do
  let(:track) { create(:track) }

  describe ".to_full" do
    it "returns all fields" do
      result = described_class.to_full(track)
      expect(result).to include(:id, :title, :track_number, :disc_number, :duration, :bitrate,
        :file_format, :file_size, :lyrics, :has_audio, :artist, :album, :created_at)
      expect(result[:artist]).to include(:id, :name)
      expect(result[:album]).to include(:id, :title)
    end
  end

  describe ".to_summary" do
    it "returns summary fields without associations" do
      result = described_class.to_summary(track)
      expect(result).to include(:id, :title, :track_number, :disc_number, :duration, :file_format, :has_audio)
      expect(result).not_to have_key(:artist)
    end
  end

  describe ".to_embedded" do
    it "returns embedded fields with associations" do
      result = described_class.to_embedded(track)
      expect(result).to include(:id, :title, :duration, :artist, :album)
      expect(result).not_to have_key(:bitrate)
    end
  end

  describe ".to_minimal" do
    it "returns minimal fields" do
      result = described_class.to_minimal(track)
      expect(result).to include(:id, :title, :artist)
      expect(result[:artist]).to eq({name: track.artist.name})
    end
  end
end
