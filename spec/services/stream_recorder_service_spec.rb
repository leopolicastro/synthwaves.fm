require "rails_helper"

RSpec.describe StreamRecorderService do
  let(:stream_url) { "https://stream.example.com/live.m3u8" }
  let(:output_path) { Rails.root.join("tmp", "test_recording.mp4").to_s }

  after { FileUtils.rm_f(output_path) }

  describe ".call" do
    it "returns a successful result when ffmpeg succeeds" do
      allow_any_instance_of(StreamRecorderService).to receive(:system).and_return(true)
      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, "fake video data")
      allow_any_instance_of(StreamRecorderService).to receive(:`).and_return("120.5\n")

      result = described_class.call(stream_url:, duration_seconds: 3600, output_path:)

      expect(result.error).to be_nil
      expect(result.output_path).to eq(output_path)
      expect(result.duration).to eq(120.5)
      expect(result.file_size).to be > 0
    end

    it "returns an error result when ffmpeg fails" do
      allow_any_instance_of(StreamRecorderService).to receive(:system).and_return(false)

      result = described_class.call(stream_url:, duration_seconds: 3600, output_path:)

      expect(result.error).to eq("ffmpeg recording failed")
      expect(result.duration).to be_nil
      expect(result.file_size).to be_nil
    end

    it "handles missing ffprobe duration gracefully" do
      allow_any_instance_of(StreamRecorderService).to receive(:system).and_return(true)
      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, "fake video data")
      allow_any_instance_of(StreamRecorderService).to receive(:`).and_return("")

      result = described_class.call(stream_url:, duration_seconds: 60, output_path:)

      expect(result.error).to be_nil
      expect(result.duration).to be_nil
    end
  end
end
