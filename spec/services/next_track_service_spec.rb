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
        RadioQueueService.new(station).populate!
        expect(NextTrackService.call(station)).to be_nil
      end
    end

    context "with tracks that have no audio files" do
      it "returns nil" do
        track = create(:track, :youtube, artist: artist, album: album, user: user)
        track.audio_file.purge if track.audio_file.attached?
        create(:playlist_track, playlist: playlist, track: track, position: 1)
        RadioQueueService.new(station).populate!

        expect(NextTrackService.call(station)).to be_nil
      end
    end

    context "shuffle mode" do
      it "returns a track with a signed URL" do
        create_track_with_audio(position: 1)
        RadioQueueService.new(station).populate!

        result = NextTrackService.call(station)

        expect(result).to be_present
        expect(result.track).to be_a(Track)
        expect(result.url).to be_present
      end

      it "advances the queue" do
        create_track_with_audio(position: 1)
        create_track_with_audio(position: 2)
        RadioQueueService.new(station).populate!

        expect {
          NextTrackService.call(station)
        }.to change { station.radio_queue_tracks.played.count }.by(1)
      end
    end

    context "sequential mode" do
      before { station.update!(playback_mode: "sequential") }

      it "returns tracks in playlist order" do
        track1 = create_track_with_audio(position: 1)
        create_track_with_audio(position: 2)
        RadioQueueService.new(station).populate!

        result = NextTrackService.call(station)
        expect(result.track).to eq(track1)
      end

      it "advances through the queue" do
        track1 = create_track_with_audio(position: 1)
        track2 = create_track_with_audio(position: 2)
        RadioQueueService.new(station).populate!

        result1 = NextTrackService.call(station)
        result2 = NextTrackService.call(station)

        expect(result1.track).to eq(track1)
        expect(result2.track).to eq(track2)
      end
    end
  end
end
