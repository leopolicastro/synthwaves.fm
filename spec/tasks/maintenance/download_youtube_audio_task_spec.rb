require "rails_helper"

RSpec.describe Maintenance::DownloadYoutubeAudioTask do
  let(:task) { described_class.new }
  let!(:admin) { create(:user, admin: true) }

  describe "#collection" do
    it "includes YouTube tracks without audio files" do
      track = create(:track, :youtube)
      expect(task.collection).to include(track)
    end

    it "excludes YouTube tracks that already have audio files" do
      track = create(:track, youtube_video_id: "abc123")
      track.audio_file.attach(
        io: StringIO.new("fake audio"),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )
      expect(task.collection).not_to include(track)
    end

    it "excludes non-YouTube tracks" do
      track = create(:track)
      expect(task.collection).not_to include(track)
    end
  end

  describe "#count" do
    it "returns the number of tracks to process" do
      create_list(:track, 3, :youtube)
      create(:track) # non-YouTube, should be excluded

      expect(task.count).to eq(3)
    end
  end

  describe "#process" do
    it "enqueues MediaDownloadJob for the track" do
      track = create(:track, :youtube)

      expect {
        task.process(track)
      }.to have_enqueued_job(MediaDownloadJob).with(
        track.id,
        "https://www.youtube.com/watch?v=#{track.youtube_video_id}",
        user_id: admin.id
      )
    end
  end
end
