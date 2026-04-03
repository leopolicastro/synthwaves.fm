require "rails_helper"

RSpec.describe TrackSearchIndexService do
  let(:track) { create(:track, title: "Test Song") }

  describe ".add" do
    it "executes an INSERT into tracks_search" do
      # The after_create_commit callback calls add automatically.
      # Verify the track is searchable (proving the insert ran).
      expect(Track.search("Test Song")).to include(track)
    end
  end

  describe ".remove" do
    it "executes a DELETE from tracks_search without error" do
      expect { described_class.remove(track) }.not_to raise_error
    end
  end

  describe ".update" do
    it "calls remove then add" do
      expect(described_class).to receive(:remove).with(track).ordered
      expect(described_class).to receive(:add).with(track).ordered

      described_class.update(track)
    end
  end
end
