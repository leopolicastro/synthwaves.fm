require "rails_helper"

RSpec.describe MetadataExtractor, type: :service do
  let(:file_path) { Rails.root.join("spec/fixtures/files/test.mp3").to_s }

  describe ".call" do
    subject(:metadata) { described_class.call(file_path) }

    it "extracts the title" do
      expect(metadata[:title]).to eq("Test Song")
    end

    it "extracts the artist" do
      expect(metadata[:artist]).to eq("Test Artist")
    end

    it "extracts the album" do
      expect(metadata[:album]).to eq("Test Album")
    end

    it "extracts the year" do
      expect(metadata[:year]).to eq(2024)
    end

    it "extracts the genre" do
      expect(metadata[:genre]).to eq("Rock")
    end

    it "extracts the track number" do
      expect(metadata[:track_number]).to eq(3)
    end

    it "extracts the disc number" do
      expect(metadata[:disc_number]).to eq(1)
    end

    it "extracts the duration" do
      expect(metadata[:duration]).to be_a(Float)
      expect(metadata[:duration]).to be > 0
    end

    it "extracts the bitrate" do
      expect(metadata[:bitrate]).to be_a(Integer)
      expect(metadata[:bitrate]).to be > 0
    end
  end

  describe "extract_cover_art" do
    it "returns nil when the file has no embedded images" do
      tag_double = instance_double(WahWah::Mp3Tag,
        title: "Test", artist: "Artist", album: "Album",
        year: "2024", genre: "Rock", track: "1", disc: "1",
        duration: 180.0, bitrate: 320, images: [])
      allow(WahWah).to receive(:open).and_return(tag_double)

      result = described_class.call("/fake/path.mp3")
      expect(result[:cover_art]).to be_nil
    end

    it "extracts the first image when present" do
      image_data = "fake image bytes"
      tag_double = instance_double(WahWah::Mp3Tag,
        title: "Test", artist: "Artist", album: "Album",
        year: "2024", genre: "Rock", track: "1", disc: "1",
        duration: 180.0, bitrate: 320,
        images: [{data: image_data, media_type: "image/jpeg"}])
      allow(WahWah).to receive(:open).and_return(tag_double)

      result = described_class.call("/fake/path.mp3")
      expect(result[:cover_art]).to eq({data: image_data, mime_type: "image/jpeg"})
    end
  end
end
