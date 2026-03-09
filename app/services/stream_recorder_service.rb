class StreamRecorderService
  Result = Data.define(:output_path, :duration, :file_size, :error)

  def self.call(stream_url:, duration_seconds:, output_path:)
    new(stream_url:, duration_seconds:, output_path:).call
  end

  def initialize(stream_url:, duration_seconds:, output_path:)
    @stream_url = stream_url
    @duration_seconds = duration_seconds
    @output_path = output_path
  end

  def call
    success = system(
      "ffmpeg", "-y",
      "-i", @stream_url,
      "-t", @duration_seconds.to_s,
      "-c", "copy",
      "-movflags", "+faststart",
      @output_path,
      out: File::NULL, err: File::NULL
    )

    unless success
      return Result.new(output_path: @output_path, duration: nil, file_size: nil, error: "ffmpeg recording failed")
    end

    duration = probe_duration(@output_path)
    file_size = File.size(@output_path)

    Result.new(output_path: @output_path, duration:, file_size:, error: nil)
  end

  private

  def probe_duration(path)
    output = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 #{Shellwords.escape(path)} 2>/dev/null`.strip
    output.present? ? output.to_f : nil
  end
end
