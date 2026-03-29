require "rails_helper"

RSpec.describe RadioQueueService do
  let(:user) { create(:user) }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:station) { create(:radio_station, playlist: playlist, user: user, status: "active") }
  let(:service) { described_class.new(station) }

  def create_track_with_audio(position:)
    track = create(:track, artist: artist, album: album, user: user)
    track.audio_file.attach(
      io: StringIO.new("fake audio"),
      filename: "track.mp3",
      content_type: "audio/mpeg"
    )
    create(:playlist_track, playlist: playlist, track: track, position: position)
    track
  end

  describe "#populate!" do
    it "creates queue entries up to WINDOW_SIZE" do
      25.times { |i| create_track_with_audio(position: i + 1) }

      service.populate!

      expect(station.radio_queue_tracks.upcoming.count).to eq(RadioQueueService::WINDOW_SIZE)
    end

    it "clears existing entries before populating" do
      track = create_track_with_audio(position: 1)
      create(:radio_queue_track, radio_station: station, track: track, position: 1)

      service.populate!

      expect(station.radio_queue_tracks.count).to eq(1)
    end

    it "creates entries matching playlist size when smaller than WINDOW_SIZE" do
      3.times { |i| create_track_with_audio(position: i + 1) }

      service.populate!

      expect(station.radio_queue_tracks.upcoming.count).to eq(3)
    end

    it "creates no entries for an empty playlist" do
      service.populate!

      expect(station.radio_queue_tracks.count).to eq(0)
    end

    context "shuffle mode" do
      it "does not duplicate tracks when playlist has enough" do
        25.times { |i| create_track_with_audio(position: i + 1) }

        service.populate!

        track_ids = station.radio_queue_tracks.upcoming.pluck(:track_id)
        expect(track_ids.uniq.size).to eq(track_ids.size)
      end
    end

    context "sequential mode" do
      before { station.update!(playback_mode: "sequential") }

      it "creates entries in playlist order" do
        tracks = 5.times.map { |i| create_track_with_audio(position: i + 1) }

        service.populate!

        queued_track_ids = station.radio_queue_tracks.upcoming.map(&:track_id)
        expect(queued_track_ids).to eq(tracks.map(&:id))
      end
    end
  end

  describe "#advance!" do
    it "marks the first upcoming entry as played" do
      track = create_track_with_audio(position: 1)
      service.populate!

      entry = service.advance!

      expect(entry.played_at).to be_present
      expect(entry.track).to eq(track)
    end

    it "backfills one track after advancing" do
      3.times { |i| create_track_with_audio(position: i + 1) }
      service.populate!
      initial_count = station.radio_queue_tracks.upcoming.count

      service.advance!

      expect(station.radio_queue_tracks.upcoming.count).to eq(initial_count)
    end

    it "returns nil when no upcoming entries exist" do
      expect(service.advance!).to be_nil
    end

    it "returns entries in queue order" do
      tracks = 5.times.map { |i| create_track_with_audio(position: i + 1) }
      station.update!(playback_mode: "sequential")
      service.populate!

      first_entry = service.advance!
      second_entry = service.advance!

      expect(first_entry.track).to eq(tracks[0])
      expect(second_entry.track).to eq(tracks[1])
    end

    context "shuffle mode with small playlist" do
      it "avoids immediate repeats when possible" do
        create_track_with_audio(position: 1)
        create_track_with_audio(position: 2)
        service.populate!

        # Advance through multiple tracks and check no consecutive repeats
        previous_track_id = nil
        4.times do
          entry = service.advance!
          if previous_track_id
            expect(entry.track_id).not_to eq(previous_track_id)
          end
          previous_track_id = entry.track_id
        end
      end
    end

    context "single-track playlist" do
      it "keeps advancing with the only available track" do
        create_track_with_audio(position: 1)
        service.populate!

        3.times do
          entry = service.advance!
          expect(entry).to be_present
        end
      end
    end
  end

  describe "#sync_with_playlist!" do
    it "removes upcoming entries for tracks no longer in the playlist" do
      tracks = 5.times.map { |i| create_track_with_audio(position: i + 1) }
      service.populate!

      # Remove a track from the playlist
      playlist.playlist_tracks.find_by(track: tracks[2]).destroy!

      service.sync_with_playlist!

      upcoming_track_ids = station.radio_queue_tracks.upcoming.pluck(:track_id)
      expect(upcoming_track_ids).not_to include(tracks[2].id)
    end

    it "backfills after removing entries" do
      tracks = 10.times.map { |i| create_track_with_audio(position: i + 1) }
      service.populate!
      initial_count = station.radio_queue_tracks.upcoming.count

      # Remove a track directly from the queue (bypassing PlaylistTrack callback)
      removed_track = tracks[0]
      PlaylistTrack.find_by(playlist: playlist, track: removed_track).delete
      service.sync_with_playlist!

      # Queue should still have same count: the stale entry was removed and backfilled
      upcoming_ids = station.radio_queue_tracks.upcoming.pluck(:track_id)
      expect(upcoming_ids).not_to include(removed_track.id)
      expect(upcoming_ids.size).to eq(initial_count - 1) # 9 tracks remain, all queued
    end

    it "does nothing when no entries are stale" do
      3.times { |i| create_track_with_audio(position: i + 1) }
      service.populate!

      expect { service.sync_with_playlist! }.not_to change {
        station.radio_queue_tracks.upcoming.count
      }
    end
  end

  describe "#clear!" do
    it "deletes all queue entries" do
      3.times { |i| create_track_with_audio(position: i + 1) }
      service.populate!

      expect { service.clear! }.to change { station.radio_queue_tracks.count }.to(0)
    end
  end

  describe "sequential wraparound" do
    before { station.update!(playback_mode: "sequential") }

    it "wraps around to the beginning after reaching the end" do
      tracks = 3.times.map { |i| create_track_with_audio(position: i + 1) }
      service.populate!

      played = 3.times.map { service.advance!.track }
      fourth = service.advance!

      expect(played).to eq(tracks)
      expect(fourth.track).to eq(tracks[0])
    end
  end
end
