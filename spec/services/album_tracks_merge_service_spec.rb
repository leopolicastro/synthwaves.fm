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
    it "returns only missing tracks" do
      owned = create(:track, album: album, artist: artist, title: "Novocaine for the Soul", track_number: 1)

      missing = described_class.call([owned], mb_tracks)

      expect(missing.length).to eq(3)
      expect(missing.all? { |e| e[:type] == :missing }).to be true
      expect(missing.map { |e| e[:title] }).to contain_exactly("Susan's House", "Rags to Rags", "Beautiful Freak")
    end

    it "matches by normalized title" do
      owned = create(:track, album: album, artist: artist, title: "NOVOCAINE FOR THE SOUL!", track_number: 99)

      missing = described_class.call([owned], mb_tracks)

      expect(missing.map { |e| e[:title] }).not_to include("Novocaine for the Soul")
    end

    it "matches by track position" do
      owned = create(:track, album: album, artist: artist, title: "Totally Different Name", track_number: 2)

      missing = described_class.call([owned], mb_tracks)

      expect(missing.map { |e| e[:position] }).not_to include(2)
    end

    it "sorts missing tracks by position" do
      missing = described_class.call([], mb_tracks)

      expect(missing.map { |e| e[:position] }).to eq([1, 2, 3, 4])
    end

    it "returns empty when all tracks are owned" do
      tracks = mb_tracks.map.with_index do |mb, i|
        create(:track, album: album, artist: artist, title: mb[:title], track_number: mb[:position])
      end

      missing = described_class.call(tracks, mb_tracks)

      expect(missing).to be_empty
    end

    it "returns empty when mb_tracks is empty" do
      owned = create(:track, album: album, artist: artist, title: "Test", track_number: 1)

      missing = described_class.call([owned], [])

      expect(missing).to be_empty
    end

    it "handles partial word matching" do
      owned = create(:track, album: album, artist: artist, title: "Eels - Novocaine for the Soul (Official)", track_number: 99)

      missing = described_class.call([owned], mb_tracks)

      expect(missing.map { |e| e[:title] }).not_to include("Novocaine for the Soul")
    end
  end
end
