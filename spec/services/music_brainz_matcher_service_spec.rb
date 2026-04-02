require "rails_helper"

RSpec.describe MusicBrainzMatcherService do
  let(:track) { create(:track, title: "Enjoy the Silence", duration: 373.0, track_number: 6) }

  describe ".call" do
    let(:matching_result) do
      {
        mbid: "abc-123",
        title: "Enjoy the Silence",
        artist_name: track.artist.name,
        artist_mbid: "artist-456",
        duration_ms: 373000,
        tags: ["synthpop"],
        releases: [{mbid: "rel-789", title: "Violator", date: "1990-03-19", country: "GB"}]
      }
    end

    it "returns the best matching result above threshold" do
      service = instance_double(MusicBrainzService)
      allow(MusicBrainzService).to receive(:new).and_return(service)
      allow(service).to receive(:search_recording).and_return([matching_result])

      result = described_class.call(track)

      expect(result).not_to be_nil
      expect(result[:mbid]).to eq("abc-123")
    end

    it "returns nil when no results match above threshold" do
      poor_match = {
        mbid: "xyz-999",
        title: "Completely Different Song",
        artist_name: "Different Artist",
        artist_mbid: "other-artist",
        duration_ms: 200000,
        tags: [],
        releases: []
      }

      service = instance_double(MusicBrainzService)
      allow(MusicBrainzService).to receive(:new).and_return(service)
      allow(service).to receive(:search_recording).and_return([poor_match])

      result = described_class.call(track)
      expect(result).to be_nil
    end

    it "returns nil when search returns no results" do
      service = instance_double(MusicBrainzService)
      allow(MusicBrainzService).to receive(:new).and_return(service)
      allow(service).to receive(:search_recording).and_return([])

      result = described_class.call(track)
      expect(result).to be_nil
    end

    context "when track has ISRC" do
      let(:track) { create(:track, title: "Enjoy the Silence", duration: 373.0, isrc: "GBAYE9000123") }

      it "tries ISRC lookup first" do
        service = instance_double(MusicBrainzService)
        allow(MusicBrainzService).to receive(:new).and_return(service)
        allow(service).to receive(:search_recording_by_isrc).and_return([matching_result])

        result = described_class.call(track)

        expect(service).to have_received(:search_recording_by_isrc).with(isrc: "GBAYE9000123")
        expect(result[:mbid]).to eq("abc-123")
      end

      it "falls back to text search when ISRC returns no results" do
        service = instance_double(MusicBrainzService)
        allow(MusicBrainzService).to receive(:new).and_return(service)
        allow(service).to receive(:search_recording_by_isrc).and_return([])
        allow(service).to receive(:search_recording).and_return([matching_result])

        result = described_class.call(track)

        expect(service).to have_received(:search_recording_by_isrc)
        expect(service).to have_received(:search_recording)
        expect(result[:mbid]).to eq("abc-123")
      end
    end
  end
end
