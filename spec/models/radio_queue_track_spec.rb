require "rails_helper"

RSpec.describe RadioQueueTrack, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:radio_station) }
    it { is_expected.to belong_to(:track) }
  end

  describe "scopes" do
    let(:station) { create(:radio_station) }
    let(:track1) { create(:track) }
    let(:track2) { create(:track) }
    let(:track3) { create(:track) }

    describe ".upcoming" do
      it "returns entries without played_at ordered by position" do
        entry2 = create(:radio_queue_track, radio_station: station, track: track2, position: 2)
        entry1 = create(:radio_queue_track, radio_station: station, track: track1, position: 1)
        create(:radio_queue_track, :played, radio_station: station, track: track3, position: 3)

        expect(station.radio_queue_tracks.upcoming).to eq([entry1, entry2])
      end
    end

    describe ".played" do
      it "returns entries with played_at ordered by most recent first" do
        create(:radio_queue_track, radio_station: station, track: track1, position: 1)
        older = create(:radio_queue_track, radio_station: station, track: track2, position: 2, played_at: 2.minutes.ago)
        newer = create(:radio_queue_track, radio_station: station, track: track3, position: 3, played_at: 1.minute.ago)

        expect(station.radio_queue_tracks.played).to eq([newer, older])
      end
    end

    describe ".recently_played" do
      it "limits the number of played entries" do
        3.times do |i|
          create(:radio_queue_track, radio_station: station, track: create(:track),
            position: i + 1, played_at: i.minutes.ago)
        end

        expect(station.radio_queue_tracks.recently_played(2).count).to eq(2)
      end
    end
  end
end
