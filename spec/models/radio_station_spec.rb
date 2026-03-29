require "rails_helper"

RSpec.describe RadioStation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:playlist) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:current_track).class_name("Track").optional }
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

  describe "#listen_url" do
    it "constructs the full Icecast URL" do
      station = build(:radio_station, mount_point: "/chill-vibes.mp3")
      expect(station.listen_url).to include("/chill-vibes.mp3")
    end
  end
end
