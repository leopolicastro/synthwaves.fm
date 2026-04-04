require "rails_helper"

RSpec.describe API::V1::TrackSerializer do
  let(:track) { create(:track) }

  describe ":full view" do
    it "returns all fields" do
      result = described_class.render_as_hash(track, view: :full)
      expect(result).to include(:id, :title, :track_number, :disc_number, :duration, :bitrate,
        :file_format, :file_size, :lyrics, :has_audio, :artist, :album, :created_at)
      expect(result[:artist]).to include(:id, :name)
      expect(result[:album]).to include(:id, :title)
    end
  end

  describe ":summary view" do
    it "returns summary fields without associations" do
      result = described_class.render_as_hash(track, view: :summary)
      expect(result).to include(:id, :title, :track_number, :disc_number, :duration, :file_format, :has_audio)
      expect(result).not_to have_key(:artist)
    end
  end

  describe ":embedded view" do
    it "returns embedded fields with associations" do
      result = described_class.render_as_hash(track, view: :embedded)
      expect(result).to include(:id, :title, :duration, :artist, :album)
      expect(result).not_to have_key(:bitrate)
    end
  end

  describe ":minimal view" do
    it "returns minimal fields" do
      result = described_class.render_as_hash(track, view: :minimal)
      expect(result).to include(:id, :title, :artist)
      expect(result[:artist]).to have_key(:name)
    end
  end
end
