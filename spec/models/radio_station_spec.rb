require "rails_helper"

RSpec.describe RadioStation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:playlist) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:current_track).class_name("Track").optional }
    it { is_expected.to have_many(:radio_queue_tracks).dependent(:delete_all) }
  end

  describe "validations" do
    subject { build(:radio_station) }

    it { is_expected.to validate_inclusion_of(:status).in_array(RadioStation::STATUSES) }
    it { is_expected.to validate_inclusion_of(:playback_mode).in_array(RadioStation::PLAYBACK_MODES) }
    it { is_expected.to validate_inclusion_of(:bitrate).in_array(RadioStation::BITRATES) }

    it { is_expected.to validate_uniqueness_of(:mount_point) }
    it { is_expected.to validate_uniqueness_of(:playlist_id) }

    it "validates mount_point format" do
      station = build(:radio_station, mount_point: "bad-format")
      expect(station).not_to be_valid
      expect(station.errors[:mount_point]).to be_present
    end

    it "accepts valid mount_point format" do
      station = build(:radio_station, mount_point: "/chill-vibes.mp3")
      expect(station).to be_valid
    end

    it { is_expected.to validate_numericality_of(:favorites_weight).is_greater_than_or_equal_to(1.0).is_less_than_or_equal_to(5.0) }

    it "validates crossfade_duration range" do
      station = build(:radio_station, crossfade_duration: 15)
      expect(station).not_to be_valid

      station.crossfade_duration = 5.0
      expect(station).to be_valid
    end
  end

  describe "status methods" do
    it "defines query methods for each status" do
      RadioStation::STATUSES.each do |status|
        station = build(:radio_station, status: status)
        expect(station.send(:"#{status}?")).to be true

        other_statuses = RadioStation::STATUSES - [status]
        other_statuses.each do |other|
          expect(station.send(:"#{other}?")).to be false
        end
      end
    end
  end

  describe "#generate_mount_point" do
    it "generates mount_point from playlist name on create" do
      playlist = create(:playlist, name: "Chill Vibes")
      station = build(:radio_station, playlist: playlist, mount_point: nil)
      station.valid?
      expect(station.mount_point).to eq("/chill-vibes.mp3")
    end

    it "does not overwrite an existing mount_point" do
      station = build(:radio_station, mount_point: "/custom.mp3")
      station.valid?
      expect(station.mount_point).to eq("/custom.mp3")
    end

    it "falls back to random hex when playlist name produces empty slug" do
      playlist = create(:playlist, name: "!!!") # parameterize returns ""
      station = build(:radio_station, playlist: playlist, mount_point: nil)
      station.valid?
      expect(station.mount_point).to match(%r{\A/[a-f0-9]+\.mp3\z})
    end
  end

  describe "#display_image" do
    it "returns the current track's album cover when attached" do
      album = create(:album, :with_cover_image)
      track = create(:track, album: album)
      station = create(:radio_station, current_track: track)

      expect(station.display_image).to eq(album.cover_image)
    end

    it "returns the station image when current track has no album cover" do
      track = create(:track)
      station = create(:radio_station, current_track: track)
      station.image.attach(io: StringIO.new("img"), filename: "station.png", content_type: "image/png")

      expect(station.display_image).to eq(station.image)
    end

    it "returns the station image when there is no current track" do
      station = create(:radio_station)
      station.image.attach(io: StringIO.new("img"), filename: "station.png", content_type: "image/png")

      expect(station.display_image).to eq(station.image)
    end

    it "returns nil when neither image is available" do
      station = create(:radio_station)
      expect(station.display_image).to be_nil
    end

    it "prefers track album cover over station image" do
      album = create(:album, :with_cover_image)
      track = create(:track, album: album)
      station = create(:radio_station, current_track: track)
      station.image.attach(io: StringIO.new("img"), filename: "station.png", content_type: "image/png")

      expect(station.display_image).to eq(album.cover_image)
    end
  end

  describe "#recently_played_tracks" do
    let(:user) { create(:user) }
    let(:artist) { create(:artist, user: user) }
    let(:album) { create(:album, artist: artist, user: user) }
    let(:playlist) { create(:playlist, user: user) }
    let(:station) { create(:radio_station, playlist: playlist, user: user, status: "active", playback_mode: "sequential") }

    def create_track_with_audio(position:)
      track = create(:track, artist: artist, album: album, user: user)
      track.audio_file.attach(io: StringIO.new("fake audio"), filename: "track.mp3", content_type: "audio/mpeg")
      create(:playlist_track, playlist: playlist, track: track, position: position)
      track
    end

    it "excludes the current and queued tracks that have not actually finished playing" do
      tracks = 5.times.map { |i| create_track_with_audio(position: i + 1) }
      service = RadioQueueService.new(station)
      service.populate!

      # Simulate Liquidsoap's next_track flow:
      # Call 1: advance pops track 1, controller queues it
      entry1 = service.advance!
      station.update!(queued_track: entry1.track)

      # Call 2: advance pops track 2, controller promotes queued->current
      entry2 = service.advance!
      station.update!(current_track: station.queued_track, queued_track: entry2.track)

      # Call 3: advance pops track 3, controller promotes again
      # Track 1 has now actually finished playing
      entry3 = service.advance!
      station.update!(current_track: station.queued_track, queued_track: entry3.track)

      recently_played = station.recently_played_tracks

      # Track 1 actually finished -- should appear
      expect(recently_played.map(&:track)).to include(tracks[0])
      # Track 2 is current_track (still playing) -- should NOT appear
      expect(recently_played.map(&:track)).not_to include(tracks[1])
      # Track 3 is queued_track (not started) -- should NOT appear
      expect(recently_played.map(&:track)).not_to include(tracks[2])
    end

    it "returns empty when only two tracks have been advanced (none actually finished)" do
      2.times { |i| create_track_with_audio(position: i + 1) }
      service = RadioQueueService.new(station)
      service.populate!

      service.advance!
      service.advance!

      expect(station.recently_played_tracks).to be_empty
    end
  end

  describe "#listen_url" do
    it "constructs the full Icecast URL" do
      station = build(:radio_station, mount_point: "/chill-vibes.mp3")
      expect(station.listen_url).to include("/chill-vibes.mp3")
    end
  end
end
