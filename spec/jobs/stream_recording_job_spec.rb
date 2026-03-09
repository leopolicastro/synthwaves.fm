require "rails_helper"

RSpec.describe StreamRecordingJob, type: :job do
  let(:channel) { create(:iptv_channel) }
  let(:recording) { create(:recording, iptv_channel: channel, starts_at: 10.minutes.ago, ends_at: 50.minutes.from_now) }
  let(:success_result) do
    StreamRecorderService::Result.new(
      output_path: Rails.root.join("tmp", "recordings", "recording_#{recording.id}.mp4").to_s,
      duration: 3600.0,
      file_size: 500_000_000,
      error: nil
    )
  end

  before do
    FileUtils.mkdir_p(Rails.root.join("tmp", "recordings"))
    output_path = Rails.root.join("tmp", "recordings", "recording_#{recording.id}.mp4").to_s
    File.write(output_path, "fake video content")
  end

  after do
    FileUtils.rm_rf(Rails.root.join("tmp", "recordings"))
  end

  describe "#perform" do
    it "records the stream and attaches the file" do
      allow(StreamRecorderService).to receive(:call).and_return(success_result)

      described_class.perform_now(recording.id)

      recording.reload
      expect(recording.status).to eq("ready")
      expect(recording.duration).to eq(3600.0)
      expect(recording.file_size).to eq(500_000_000)
      expect(recording.file).to be_attached
    end

    it "transitions through recording and processing states" do
      statuses = []
      allow(recording).to receive(:broadcast_status) { statuses << recording.status }
      allow(Recording).to receive(:find).with(recording.id).and_return(recording)
      allow(StreamRecorderService).to receive(:call).and_return(success_result)

      described_class.perform_now(recording.id)

      expect(statuses).to eq(%w[recording processing ready])
    end

    it "skips cancelled recordings" do
      recording.update!(status: "cancelled")

      expect(StreamRecorderService).not_to receive(:call)

      described_class.perform_now(recording.id)
    end

    it "marks as failed when recording window has passed" do
      recording.update!(ends_at: 1.minute.ago)

      described_class.perform_now(recording.id)

      recording.reload
      expect(recording.status).to eq("failed")
      expect(recording.error_message).to eq("Recording window has already passed")
    end

    it "marks as failed when ffmpeg fails" do
      failed_result = StreamRecorderService::Result.new(
        output_path: Rails.root.join("tmp", "recordings", "recording_#{recording.id}.mp4").to_s,
        duration: nil,
        file_size: nil,
        error: "ffmpeg recording failed"
      )
      allow(StreamRecorderService).to receive(:call).and_return(failed_result)

      described_class.perform_now(recording.id)

      recording.reload
      expect(recording.status).to eq("failed")
      expect(recording.error_message).to eq("ffmpeg recording failed")
    end

    it "cleans up temp files after completion" do
      allow(StreamRecorderService).to receive(:call).and_return(success_result)

      described_class.perform_now(recording.id)

      expect(File.exist?(success_result.output_path)).to be false
    end
  end
end
