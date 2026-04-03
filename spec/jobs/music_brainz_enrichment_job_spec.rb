require "rails_helper"

RSpec.describe MusicBrainzEnrichmentJob do
  let(:track) { create(:track) }

  describe "#perform" do
    it "calls MusicBrainzEnricherService with the track" do
      expect(MusicBrainzEnricherService).to receive(:call).with(track)
      described_class.perform_now(track.id)
    end

    it "discards when track is not found" do
      expect(MusicBrainzEnricherService).not_to receive(:call)
      described_class.perform_now(-1)
    end
  end
end
