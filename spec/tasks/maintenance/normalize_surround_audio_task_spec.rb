require "rails_helper"

RSpec.describe Maintenance::NormalizeSurroundAudioTask do
  let(:user) { create(:user) }
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes videos with surround audio" do
      surround = create(:video, user: user, audio_channels: 6)
      expect(task.collection).to include(surround)
    end

    it "includes videos with nil audio_channels" do
      unprobed = create(:video, user: user, audio_channels: nil)
      expect(task.collection).to include(unprobed)
    end

    it "excludes videos with stereo audio" do
      stereo = create(:video, user: user, audio_channels: 2)
      expect(task.collection).not_to include(stereo)
    end

    it "excludes non-ready videos" do
      processing = create(:video, user: user, audio_channels: nil, status: "processing")
      expect(task.collection).not_to include(processing)
    end
  end

  describe "#process" do
    it "re-encodes video with surround audio to stereo" do
      video = create(:video, user: user, audio_channels: 6)
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      surround_metadata = {audio_channels: 6, audio_codec: "aac", bitrate: 5000}
      stereo_metadata = {audio_channels: 2, audio_codec: "aac", bitrate: 3000}

      allow(VideoMetadataExtractor).to receive(:call).and_return(surround_metadata, stereo_metadata)
      allow(task).to receive(:system) do |*args|
        # Create the output file that ffmpeg would produce
        args.last(3).first # the arg before out:/err: options
        # Find the output_path from args (it's the last positional arg before keyword-style args)
        output_file = args.find { |a| a.is_a?(String) && a.end_with?(".normalized.mp4") }
        File.write(output_file, "converted video") if output_file
        true
      end

      task.process(video)

      video.reload
      expect(video.audio_channels).to eq(2)
    end

    it "updates audio_channels without re-encoding for stereo video" do
      video = create(:video, user: user, audio_channels: nil)
      video.file.attach(io: StringIO.new("fake video"), filename: "test.mp4", content_type: "video/mp4")

      stereo_metadata = {audio_channels: 2, audio_codec: "aac", bitrate: 5000}
      allow(VideoMetadataExtractor).to receive(:call).and_return(stereo_metadata)
      allow(task).to receive(:system).and_call_original

      task.process(video)

      video.reload
      expect(video.audio_channels).to eq(2)
      expect(task).not_to have_received(:system)
    end

    it "skips video with no file attached" do
      video = create(:video, user: user, audio_channels: nil)

      expect { task.process(video) }.not_to raise_error
    end
  end
end
