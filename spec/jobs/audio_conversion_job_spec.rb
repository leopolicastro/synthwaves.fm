require "rails_helper"

RSpec.describe AudioConversionJob, type: :job do
  let(:track) { create(:track, file_format: "webm") }

  describe "#perform" do
    it "skips when no audio file is attached" do
      expect { described_class.perform_now(track.id) }.not_to raise_error
    end

    it "skips when file format is already mp3" do
      track.update!(file_format: "mp3")
      track.audio_file.attach(
        io: StringIO.new("fake audio"),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      expect { described_class.perform_now(track.id) }.not_to raise_error
      expect(track.reload.file_format).to eq("mp3")
    end

    context "with an attached webm file" do
      let(:webm_path) { Rails.root.join("spec/fixtures/files/test.webm") }

      before do
        # Create a tiny valid webm using ffmpeg from the test mp3
        mp3_path = Rails.root.join("spec/fixtures/files/test.mp3")
        system("ffmpeg", "-y", "-i", mp3_path.to_s, "-c:a", "libopus", "-b:a", "64k", webm_path.to_s,
          out: File::NULL, err: File::NULL)

        track.audio_file.attach(
          io: File.open(webm_path),
          filename: "test.webm",
          content_type: "audio/webm"
        )
      end

      after do
        FileUtils.rm_f(webm_path)
      end

      it "converts the file to mp3 and replaces the attachment" do
        described_class.perform_now(track.id)
        track.reload

        expect(track.file_format).to eq("mp3")
        expect(track.audio_file.filename.to_s).to end_with(".mp3")
        expect(track.audio_file.content_type).to eq("audio/mpeg")
      end

      it "extracts metadata from the converted mp3" do
        track.update!(duration: nil, bitrate: nil)

        described_class.perform_now(track.id)
        track.reload

        expect(track.duration).to be_present
        expect(track.duration).to be > 0
        expect(track.bitrate).to be_present
      end

      it "updates artist and album when they were unknown" do
        track.artist.update!(name: "Unknown Artist")
        track.album.update!(title: "Unknown Album")

        allow(MetadataExtractor).to receive(:call).and_return({
          title: "Real Title", artist: "Real Artist", album: "Real Album",
          track_number: 1, disc_number: 1, duration: 60.0, bitrate: 192, cover_art: nil
        })

        described_class.perform_now(track.id)
        track.reload

        expect(track.title).to eq("Real Title")
        expect(track.artist.name).to eq("Real Artist")
        expect(track.album.title).to eq("Real Album")
      end

      it "cleans up the temporary files" do
        described_class.perform_now(track.id)

        temp_files = Dir.glob(File.join(Dir.tmpdir, "audio_conversion_*"))
        expect(temp_files).to be_empty
      end
    end
  end
end
