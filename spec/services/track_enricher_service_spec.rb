require "rails_helper"

RSpec.describe TrackEnricherService do
  let(:track) { create(:track, title: "Get Lucky", duration: 369.0) }

  describe ".call" do
    context "when Apple Music match is found" do
      let(:match) do
        {
          apple_music_id: "123",
          name: "Get Lucky",
          artist_name: track.artist.name,
          album_name: "Random Access Memories",
          genre_names: ["Electronic", "Dance", "Music"],
          isrc: "USCO11300095",
          content_rating: "explicit",
          release_date: "2013-05-17",
          duration_ms: 369000,
          disc_number: 1,
          track_number: 8
        }
      end

      before do
        allow(AppleMusicMatcherService).to receive(:call).with(track).and_return(match)
        allow(LanguageDetectorService).to receive(:call).with(track).and_return("en")
      end

      it "returns :matched" do
        result = described_class.call(track)
        expect(result).to eq(:matched)
      end

      it "updates track with Apple Music metadata" do
        described_class.call(track)
        track.reload

        expect(track.apple_music_id).to eq("123")
        expect(track.content_rating).to eq("explicit")
        expect(track.enrichment_status).to eq("matched")
        expect(track.enriched_at).to be_present
      end

      it "sets release_year when not already set" do
        described_class.call(track)
        track.reload
        expect(track.release_year).to eq(2013)
      end

      it "does not overwrite existing release_year" do
        track.update!(release_year: 1990)

        described_class.call(track)
        track.reload
        expect(track.release_year).to eq(1990)
      end

      it "sets ISRC when not already set" do
        described_class.call(track)
        track.reload
        expect(track.isrc).to eq("USCO11300095")
      end

      it "does not overwrite existing ISRC" do
        track.update!(isrc: "EXISTING123")

        described_class.call(track)
        track.reload
        expect(track.isrc).to eq("EXISTING123")
      end

      it "detects and stores language" do
        described_class.call(track)
        track.reload
        expect(track.language).to eq("en")
      end

      it "does not overwrite existing language" do
        track.update!(language: "ja")
        allow(LanguageDetectorService).to receive(:call).and_return("en")

        described_class.call(track)
        track.reload
        expect(track.language).to eq("ja")
      end
    end

    context "when no Apple Music match is found" do
      before do
        allow(AppleMusicMatcherService).to receive(:call).with(track).and_return(nil)
      end

      it "returns :unmatched" do
        result = described_class.call(track)
        expect(result).to eq(:unmatched)
      end

      it "sets enrichment_status to unmatched" do
        described_class.call(track)
        track.reload
        expect(track.enrichment_status).to eq("unmatched")
        expect(track.enriched_at).to be_present
      end
    end

    context "when track was recently enriched" do
      before do
        track.update!(enrichment_status: "matched", enriched_at: 1.day.ago)
      end

      it "returns :skipped" do
        result = described_class.call(track)
        expect(result).to eq(:skipped)
      end
    end

    context "when an error occurs" do
      before do
        allow(AppleMusicMatcherService).to receive(:call).and_raise(AppleMusicService::Error, "API error")
      end

      it "returns :failed" do
        result = described_class.call(track)
        expect(result).to eq(:failed)
      end

      it "sets enrichment_status to failed" do
        described_class.call(track)
        track.reload
        expect(track.enrichment_status).to eq("failed")
      end
    end
  end
end
