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
          confidence: 0.95,
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

    context "when match confidence is high and artist differs" do
      let(:wrong_artist) { create(:artist, user: track.user, name: "Wrong Artist") }
      let(:wrong_album) { create(:album, artist: wrong_artist, user: track.user, title: "Wrong Album") }

      let(:reassign_match) do
        {
          mbid: "abc-123",
          title: "Enjoy the Silence",
          artist_name: "Depeche Mode",
          artist_mbid: "dm-mbid-456",
          duration_ms: 373000,
          confidence: 0.95,
          tags: [],
          releases: [{mbid: "rel-789", title: "Violator", date: "1990-03-19", country: "GB"}]
        }
      end

      before do
        track.update!(artist: wrong_artist, album: wrong_album)
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(reassign_match)
      end

      it "reassigns track to the correct artist" do
        described_class.call(track)
        track.reload

        expect(track.artist.name).to eq("Depeche Mode")
        expect(track.artist.musicbrainz_artist_id).to eq("dm-mbid-456")
      end

      it "reassigns track to the correct album" do
        described_class.call(track)
        track.reload

        expect(track.album.title).to eq("Violator")
      end

      it "cleans up empty artist and album" do
        described_class.call(track)

        expect(Artist.find_by(id: wrong_artist.id)).to be_nil
        expect(Album.find_by(id: wrong_album.id)).to be_nil
      end

      it "does not reassign when confidence is below threshold" do
        low_match = reassign_match.merge(confidence: 0.7)
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(low_match)

        described_class.call(track)
        track.reload

        expect(track.artist.name).to eq("Wrong Artist")
      end

      it "does not reassign when artist name matches" do
        same_match = reassign_match.merge(artist_name: wrong_artist.name)
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(same_match)

        described_class.call(track)
        track.reload

        expect(track.artist).to eq(wrong_artist)
      end
    end

    context "Apple Music chaining" do
      before do
        allow(MusicBrainzMatcherService).to receive(:call).with(track).and_return(nil)
      end

      it "queues Apple Music enrichment when flag is enabled" do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:apple_music_enrichment).and_return(true)

        expect(AppleMusicEnrichmentJob).to receive(:set).with(wait: 5.seconds).and_return(AppleMusicEnrichmentJob)
        expect(AppleMusicEnrichmentJob).to receive(:perform_later).with(track.id)

        described_class.call(track)
      end

      it "does not queue Apple Music when flag is disabled" do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:apple_music_enrichment).and_return(false)

        expect(AppleMusicEnrichmentJob).not_to receive(:set)

        described_class.call(track)
      end
    end
  end
end
