require "rails_helper"

RSpec.describe PlaylistMergeService do
  let(:user) { create(:user) }
  let(:target) { create(:playlist, user: user) }
  let(:source) { create(:playlist, user: user) }
  let(:track1) { create(:track) }
  let(:track2) { create(:track) }
  let(:track3) { create(:track) }

  before do
    target.playlist_tracks.create!(track: track1, position: 1)
    source.playlist_tracks.create!(track: track2, position: 1)
    source.playlist_tracks.create!(track: track3, position: 2)
  end

  describe ".call" do
    it "moves tracks from source to target" do
      described_class.call(target: target, source: source)

      expect(target.tracks.reload).to include(track1, track2, track3)
    end

    it "appends tracks after existing ones" do
      described_class.call(target: target, source: source)

      positions = target.playlist_tracks.reload.order(:position).pluck(:track_id, :position)
      expect(positions).to eq([[track1.id, 1], [track2.id, 2], [track3.id, 3]])
    end

    it "skips duplicate tracks" do
      target.playlist_tracks.create!(track: track2, position: 2)

      described_class.call(target: target, source: source)

      expect(target.playlist_tracks.where(track_id: track2.id).count).to eq(1)
    end

    it "destroys the source playlist" do
      described_class.call(target: target, source: source)

      expect { source.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not destroy tracks" do
      described_class.call(target: target, source: source)

      expect(Track.exists?(track2.id)).to be true
      expect(Track.exists?(track3.id)).to be true
    end

    it "raises an error when merging into itself" do
      expect {
        described_class.call(target: target, source: target)
      }.to raise_error(PlaylistMergeService::Error, "Cannot merge a playlist into itself.")
    end
  end
end
