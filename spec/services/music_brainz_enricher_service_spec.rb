require "rails_helper"

RSpec.describe MusicBrainzEnricherService do
  let(:track) { create(:track, title: "Enjoy the Silence", duration: 373.0) }

  describe ".call" do
    context "when MusicBrainz match is found" do
      let(:match) do
        {
          mbid: "abc-123",
          title: "Enjoy the Silence",
          artist_name: track.artist.name,
          artist_mbid: "artist-456",
          duration_ms: 373000,
          tags: ["synthpop", "electronic", "new wave"],
          releases: [{mbid: "rel-789", title: track.album.title, date: "1990-03-19", country: "GB"}]
        }
      end

      before do
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(match)
      end

      it "returns :matched" do
        result = described_class.call(track)
        expect(result).to eq(:matched)
      end

      it "updates track with MusicBrainz recording ID" do
        described_class.call(track)
        track.reload

        expect(track.musicbrainz_recording_id).to eq("abc-123")
        expect(track.musicbrainz_enrichment_status).to eq("matched")
        expect(track.musicbrainz_enriched_at).to be_present
      end

      it "creates genre tags from MusicBrainz tags" do
        described_class.call(track)

        tag_names = track.tags.pluck(:name)
        expect(tag_names).to include("synthpop", "electronic", "new wave")
      end

      it "sets release_year when not already set" do
        described_class.call(track)
        track.reload

        expect(track.release_year).to eq(1990)
      end

      it "does not overwrite existing release_year" do
        track.update!(release_year: 2013)

        described_class.call(track)
        track.reload

        expect(track.release_year).to eq(2013)
      end

      it "updates album with MusicBrainz release ID" do
        described_class.call(track)
        track.album.reload

        expect(track.album.musicbrainz_release_id).to eq("rel-789")
      end

      it "updates artist with MusicBrainz artist ID" do
        described_class.call(track)
        track.artist.reload

        expect(track.artist.musicbrainz_artist_id).to eq("artist-456")
      end

      it "filters out generic tags" do
        match_with_generic = match.merge(tags: ["music", "synthpop"])
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(match_with_generic)

        described_class.call(track)

        tag_names = track.tags.pluck(:name)
        expect(tag_names).to include("synthpop")
        expect(tag_names).not_to include("music")
      end
    end

    context "when no MusicBrainz match is found" do
      before do
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(nil)
      end

      it "returns :unmatched" do
        result = described_class.call(track)
        expect(result).to eq(:unmatched)
      end

      it "sets musicbrainz_enrichment_status to unmatched" do
        described_class.call(track)
        track.reload
        expect(track.musicbrainz_enrichment_status).to eq("unmatched")
        expect(track.musicbrainz_enriched_at).to be_present
      end
    end

    context "when track was recently enriched" do
      before do
        track.update!(musicbrainz_enrichment_status: "matched", musicbrainz_enriched_at: 1.day.ago)
      end

      it "returns :skipped" do
        result = described_class.call(track)
        expect(result).to eq(:skipped)
      end
    end

    context "when enrichment was over 30 days ago" do
      before do
        track.update!(musicbrainz_enrichment_status: "matched", musicbrainz_enriched_at: 31.days.ago)
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(nil)
      end

      it "re-enriches the track" do
        result = described_class.call(track)
        expect(result).to eq(:unmatched)
      end
    end

    context "when an error occurs" do
      before do
        allow(MusicBrainzMatcherService).to receive(:call).and_raise(MusicBrainzService::Error, "API error")
      end

      it "returns :failed" do
        result = described_class.call(track)
        expect(result).to eq(:failed)
      end

      it "sets musicbrainz_enrichment_status to failed" do
        described_class.call(track)
        track.reload
        expect(track.musicbrainz_enrichment_status).to eq("failed")
      end
    end

    context "Apple Music chaining" do
      before do
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(nil)
      end

      it "queues Apple Music enrichment after enriching" do
        expect(AppleMusicEnrichmentJob).to receive(:set).with(wait: 5.seconds).and_return(AppleMusicEnrichmentJob)
        expect(AppleMusicEnrichmentJob).to receive(:perform_later).with(track.id)

        described_class.call(track)
      end
    end
  end
end
