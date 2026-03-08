require "rails_helper"

RSpec.describe MetadataExtractionJob, type: :job do
  let(:track) { create(:track, title: "Original Title", duration: nil, bitrate: nil) }

  describe "#perform" do
    it "skips when no audio file is attached" do
      expect { described_class.perform_now(track.id) }.not_to raise_error
      expect(track.reload.title).to eq("Original Title")
    end

    context "with an attached audio file" do
      before do
        track.audio_file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )
      end

      it "updates track metadata from the audio file" do
        described_class.perform_now(track.id)
        track.reload
        expect(track.title).to eq("Test Song")
        expect(track.duration).to be > 0
        expect(track.bitrate).to be > 0
      end

      it "preserves existing values when metadata returns nil for a field" do
        track.update!(track_number: 7, disc_number: 2)

        allow(MetadataExtractor).to receive(:call).and_return({
          title: nil, track_number: nil, disc_number: nil, duration: nil, bitrate: nil, cover_art: nil
        })

        described_class.perform_now(track.id)
        track.reload
        expect(track.title).to eq("Original Title")
        expect(track.track_number).to eq(7)
        expect(track.disc_number).to eq(2)
      end

      it "attaches cover art to album when metadata includes it" do
        allow(MetadataExtractor).to receive(:call).and_return({
          title: "Test Song", track_number: 1, disc_number: 1, duration: 60.0, bitrate: 128,
          cover_art: {data: "fake image data", mime_type: "image/jpeg"}
        })

        described_class.perform_now(track.id)
        expect(track.album.reload.cover_image.attached?).to be true
      end

      it "does not overwrite existing album cover art" do
        track.album.cover_image.attach(
          io: StringIO.new("existing cover"),
          filename: "existing.jpg",
          content_type: "image/jpeg"
        )

        allow(MetadataExtractor).to receive(:call).and_return({
          title: "Test Song", track_number: 1, disc_number: 1, duration: 60.0, bitrate: 128,
          cover_art: {data: "new image data", mime_type: "image/jpeg"}
        })

        original_blob_id = track.album.cover_image.blob.id
        described_class.perform_now(track.id)
        expect(track.album.reload.cover_image.blob.id).to eq(original_blob_id)
      end
    end
  end
end
