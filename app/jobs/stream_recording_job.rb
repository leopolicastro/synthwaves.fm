class StreamRecordingJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find(recording_id)
    return if recording.cancelled?

    remaining = recording.ends_at - Time.current
    return mark_failed(recording, "Recording window has already passed") if remaining <= 0

    recording.update!(status: "recording")
    recording.broadcast_status

    output_path = Rails.root.join("tmp", "recordings", "recording_#{recording.id}.mp4").to_s
    FileUtils.mkdir_p(File.dirname(output_path))

    result = StreamRecorderService.call(
      stream_url: recording.iptv_channel.stream_url,
      duration_seconds: remaining.to_i,
      output_path: output_path
    )

    if result.error
      mark_failed(recording, result.error)
      return
    end

    recording.update!(status: "processing")
    recording.broadcast_status

    recording.file.attach(
      io: File.open(result.output_path),
      filename: recording.filename,
      content_type: "video/mp4"
    )

    recording.update!(
      status: "ready",
      duration: result.duration,
      file_size: result.file_size
    )
    recording.broadcast_status
  rescue => e
    mark_failed(recording, e.message) if recording
    raise
  ensure
    FileUtils.rm_f(output_path) if output_path
  end

  private

  def mark_failed(recording, message)
    recording.update!(status: "failed", error_message: message)
    recording.broadcast_status
  end
end
