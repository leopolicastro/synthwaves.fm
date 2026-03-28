require "rails_helper"

RSpec.describe NextTrackService do
  let(:user) { create(:user) }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:station) { create(:radio_station, playlist: playlist, user: user, status: "active") }

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

  describe ".call" do
    context "with an empty playlist" do
      it "returns nil" do
        expect(NextTrackService.call(station)).to be_nil
      end
    end

    context "with tracks that have no audio files" do
      it "returns nil" do
        track = create(:track, :youtube, artist: artist, album: album, user: user)
        track.audio_file.purge if track.audio_file.attached?
        create(:playlist_track, playlist: playlist, track: track, position: 1)

        expect(NextTrackService.call(station)).to be_nil
      end
    end

    context "shuffle mode" do
      it "returns a track with a signed URL" do
        create_track_with_audio(position: 1)

        result = NextTrackService.call(station)

        expect(result).to be_present
        expect(result.track).to be_a(Track)
        expect(result.url).to be_present
      end

      it "updates the station's queued_track" do
        track = create_track_with_audio(position: 1)

        expect {
          NextTrackService.call(station)
        }.to change { station.reload.queued_track }.to(track)
      end

      it "avoids repeating the queued track when possible" do
        create_track_with_audio(position: 1)
        track2 = create_track_with_audio(position: 2)
        station.update!(queued_track: track2)

        # With 2 tracks and queued=track2, next should always be track1 (not track2)
        result = NextTrackService.call(station)
        expect(result.track).not_to eq(track2)
      end

      it "allows the only track to repeat" do
        create_track_with_audio(position: 1)

        result = NextTrackService.call(station)
        expect(result).to be_present
      end
    end

    context "sequential mode" do
      before { station.update!(playback_mode: "sequential") }

      it "starts with the first track" do
        track1 = create_track_with_audio(position: 1)
        create_track_with_audio(position: 2)

        result = NextTrackService.call(station)
        expect(result.track).to eq(track1)
      end

      it "advances to the next track" do
        track1 = create_track_with_audio(position: 1)
        track2 = create_track_with_audio(position: 2)
        station.update!(queued_track: track1)

        result = NextTrackService.call(station)
        expect(result.track).to eq(track2)
      end

      it "wraps around to the first track" do
        track1 = create_track_with_audio(position: 1)
        track2 = create_track_with_audio(position: 2)
        station.update!(queued_track: track2)

        result = NextTrackService.call(station)
        expect(result.track).to eq(track1)
      end

      it "skips tracks without audio files" do
        track1 = create_track_with_audio(position: 1)
        # Track at position 2 has no audio
        track_no_audio = create(:track, :youtube, artist: artist, album: album, user: user)
        track_no_audio.audio_file.purge if track_no_audio.audio_file.attached?
        create(:playlist_track, playlist: playlist, track: track_no_audio, position: 2)
        track3 = create_track_with_audio(position: 3)

        station.update!(queued_track: track1)

        result = NextTrackService.call(station)
        expect(result.track).to eq(track3)
      end
    end
  end
end
