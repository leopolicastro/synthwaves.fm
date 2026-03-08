require "rails_helper"

RSpec.describe Track, type: :model do
  describe "associations" do
    it { should belong_to(:album) }
    it { should belong_to(:artist) }
    it { should have_one_attached(:audio_file) }
    it { should have_many(:playlist_tracks).dependent(:destroy) }
    it { should have_many(:playlists).through(:playlist_tracks) }
    it { should have_many(:play_histories).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
  end

  describe "callbacks" do
    it "enqueues AudioConversionJob for webm files" do
      track = build(:track, file_format: "webm")
      track.audio_file.attach(
        io: StringIO.new("fake audio"),
        filename: "test.webm",
        content_type: "audio/webm"
      )

      expect { track.save! }.to have_enqueued_job(AudioConversionJob).with(track.id)
    end

    it "does not enqueue AudioConversionJob for mp3 files" do
      track = build(:track, file_format: "mp3")
      track.audio_file.attach(
        io: StringIO.new("fake audio"),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      expect { track.save! }.not_to have_enqueued_job(AudioConversionJob)
    end
  end
end
