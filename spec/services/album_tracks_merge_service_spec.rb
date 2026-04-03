require "rails_helper"

RSpec.describe AlbumTracksMergeService do
  let(:artist) { create(:artist) }
  let(:album) { create(:album, artist: artist) }

  let(:mb_tracks) do
    [
      {position: 1, title: "Novocaine for the Soul", duration_ms: 188000},
      {position: 2, title: "Susan's House", duration_ms: 223000},
      {position: 3, title: "Rags to Rags", duration_ms: 233000},
      {position: 4, title: "Beautiful Freak", duration_ms: 214000}
    ]
  end

  describe ".call" do
    it "marks owned and missing tracks" do
      owned = create(:track, album: album, artist: artist, title: "Novocaine for the Soul", track_number: 1)

      entries = described_class.call([owned], mb_tracks)

      owned_entries = entries.select { |e| e[:type] == :owned }
      missing_entries = entries.select { |e| e[:type] == :missing }

      expect(owned_entries.length).to eq(1)
      expect(missing_entries.length).to eq(3)
      expect(missing_entries.map { |e| e[:title] }).to contain_exactly("Susan's House", "Rags to Rags", "Beautiful Freak")
    end

    it "matches by normalized title" do
      owned = create(:track, album: album, artist: artist, title: "NOVOCAINE FOR THE SOUL!", track_number: 1)

      entries = described_class.call([owned], mb_tracks)
      missing_titles = entries.select { |e| e[:type] == :missing }.map { |e| e[:title] }

      expect(missing_titles).not_to include("Novocaine for the Soul")
    end

    it "matches by track position as fallback" do
      owned = create(:track, album: album, artist: artist, title: "Totally Different Name", track_number: 2)

      entries = described_class.call([owned], mb_tracks)
      missing_positions = entries.select { |e| e[:type] == :missing }.map { |e| e[:position] }

      expect(missing_positions).not_to include(2)
    end

    it "sorts by position" do
      owned = create(:track, album: album, artist: artist, title: "Beautiful Freak", track_number: 4)

      entries = described_class.call([owned], mb_tracks)
      positions = entries.map { |e| e[:position] }

      expect(positions).to eq([1, 2, 3, 4])
    end

    it "returns only owned entries when mb_tracks is empty" do
      owned = create(:track, album: album, artist: artist, title: "Test", track_number: 1)

      entries = described_class.call([owned], [])

      expect(entries.length).to eq(1)
      expect(entries.first[:type]).to eq(:owned)
    end
  end
end
