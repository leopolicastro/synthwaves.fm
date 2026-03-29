require "rails_helper"

RSpec.describe AppleMusicEnrichmentJob do
  let(:track) { create(:track) }

  describe "#perform" do
    it "calls TrackEnricherService with the track" do
      expect(TrackEnricherService).to receive(:call).with(track)
      described_class.perform_now(track.id)
    end

    it "discards when track is not found" do
      expect(TrackEnricherService).not_to receive(:call)
      described_class.perform_now(-1)
    end
  end
end
