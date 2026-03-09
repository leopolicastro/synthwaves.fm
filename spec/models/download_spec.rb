require "rails_helper"

RSpec.describe Download, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      download = build(:download)
      expect(download).to be_valid
    end

    it "validates downloadable_type inclusion" do
      download = build(:download, downloadable_type: "Invalid", downloadable: nil)
      expect(download).not_to be_valid
      expect(download.errors[:downloadable_type]).to be_present
    end

    it "validates status inclusion" do
      download = build(:download, status: "unknown")
      expect(download).not_to be_valid
      expect(download.errors[:status]).to be_present
    end

    it "allows nil downloadable for Library type" do
      download = build(:download, downloadable_type: "Library", downloadable: nil)
      expect(download).to be_valid
    end
  end

  describe "scopes" do
    describe ".expired" do
      it "returns ready downloads older than 1 hour" do
        expired = create(:download, :ready, updated_at: 2.hours.ago)
        fresh = create(:download, :ready, updated_at: 30.minutes.ago)
        pending = create(:download, updated_at: 2.hours.ago)

        expect(Download.expired).to include(expired)
        expect(Download.expired).not_to include(fresh)
        expect(Download.expired).not_to include(pending)
      end
    end

    describe ".stale" do
      it "returns pending/processing downloads older than 6 hours" do
        stale_pending = create(:download, status: "pending", created_at: 7.hours.ago)
        stale_processing = create(:download, :processing, created_at: 7.hours.ago)
        fresh_pending = create(:download, status: "pending", created_at: 1.hour.ago)
        ready_old = create(:download, :ready, created_at: 7.hours.ago)

        result = Download.stale
        expect(result).to include(stale_pending, stale_processing)
        expect(result).not_to include(fresh_pending)
        expect(result).not_to include(ready_old)
      end
    end
  end

  describe "status predicates" do
    it "returns true for pending?" do
      expect(build(:download, status: "pending")).to be_pending
    end

    it "returns true for processing?" do
      expect(build(:download, status: "processing")).to be_processing
    end

    it "returns true for ready?" do
      expect(build(:download, status: "ready")).to be_ready
    end

    it "returns true for failed?" do
      expect(build(:download, status: "failed")).to be_failed
    end
  end

  describe "#progress_percentage" do
    it "returns 0 when total_tracks is zero" do
      download = build(:download, total_tracks: 0, processed_tracks: 0)
      expect(download.progress_percentage).to eq(0)
    end

    it "calculates percentage correctly" do
      download = build(:download, total_tracks: 10, processed_tracks: 7)
      expect(download.progress_percentage).to eq(70)
    end
  end

  describe "#filename" do
    it "generates filename for Album downloads" do
      artist = build(:artist, name: "Pink Floyd")
      album = build(:album, title: "The Wall", artist: artist)
      download = build(:download, downloadable_type: "Album", downloadable: album)

      expect(download.filename).to eq("Pink Floyd - The Wall.zip")
    end

    it "generates filename for Playlist downloads" do
      playlist = build(:playlist, name: "Road Trip Jams")
      download = build(:download, downloadable_type: "Playlist", downloadable: playlist)

      expect(download.filename).to eq("Road Trip Jams.zip")
    end

    it "generates filename for Library exports" do
      download = build(:download, downloadable_type: "Library", downloadable: nil)

      expect(download.filename).to eq("SynthWaves Library Export.zip")
    end

    it "generates filename for Track downloads" do
      artist = build(:artist, name: "Daft Punk")
      track = build(:track, title: "Around the World", artist: artist)
      download = build(:download, downloadable_type: "Track", downloadable: track)

      expect(download.filename).to eq("Daft Punk - Around the World.zip")
    end
  end
end
