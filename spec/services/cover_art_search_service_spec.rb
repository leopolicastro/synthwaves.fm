require "rails_helper"

RSpec.describe CoverArtSearchService do
  let(:album) { create(:album) }

  describe "#call" do
    context "when audio file has embedded cover art" do
      it "attaches cover from audio metadata and returns :audio" do
        track = create(:track, album: album)
        track.audio_file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )

        cover_art = {data: "fake-image-data", mime_type: "image/jpeg"}
        allow(MetadataExtractor).to receive(:call).and_return(
          {cover_art: cover_art, title: "Test"}
        )

        result = described_class.call(album)

        expect(result).to eq(:audio)
        expect(album.cover_image).to be_attached
      end
    end

    context "when track has a youtube_video_id" do
      it "fetches YouTube thumbnail and returns :youtube" do
        create(:track, album: album, youtube_video_id: "abc123")

        stub_request(:get, "https://itunes.apple.com/search")
          .with(query: hash_including(entity: "album"))
          .to_return(status: 200, body: {results: []}.to_json, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "https://img.youtube.com/vi/abc123/hqdefault.jpg")
          .to_return(
            status: 200,
            body: "fake-image-data",
            headers: {"Content-Type" => "image/jpeg"}
          )

        result = described_class.call(album)

        expect(result).to eq(:youtube)
        expect(album.cover_image).to be_attached
      end

      it "falls through when YouTube returns an error" do
        create(:track, album: album, youtube_video_id: "bad123")

        stub_request(:get, "https://itunes.apple.com/search")
          .with(query: hash_including(term: anything))
          .to_return(status: 200, body: {results: []}.to_json, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "https://img.youtube.com/vi/bad123/hqdefault.jpg")
          .to_return(status: 404)

        result = described_class.call(album)

        expect(result).to eq(:not_found)
      end
    end

    context "when iTunes has artwork" do
      it "fetches iTunes artwork and returns :itunes" do
        create(:track, album: album)

        itunes_response = {
          results: [{
            "artworkUrl100" => "https://example.com/art/100x100bb.jpg"
          }]
        }.to_json

        stub_request(:get, "https://itunes.apple.com/search")
          .with(query: hash_including(entity: "album", limit: "1"))
          .to_return(status: 200, body: itunes_response, headers: {"Content-Type" => "application/json"})

        stub_request(:get, "https://example.com/art/600x600bb.jpg")
          .to_return(status: 200, body: "fake-image-data", headers: {"Content-Type" => "image/jpeg"})

        result = described_class.call(album)

        expect(result).to eq(:itunes)
        expect(album.cover_image).to be_attached
      end

      it "upsizes artwork URL from 100x100 to 600x600" do
        create(:track, album: album)

        itunes_response = {
          results: [{
            "artworkUrl100" => "https://example.com/art/100x100bb.jpg"
          }]
        }.to_json

        stub_request(:get, "https://itunes.apple.com/search")
          .with(query: hash_including(entity: "album"))
          .to_return(status: 200, body: itunes_response, headers: {"Content-Type" => "application/json"})

        hq_stub = stub_request(:get, "https://example.com/art/600x600bb.jpg")
          .to_return(status: 200, body: "fake-image-data", headers: {"Content-Type" => "image/jpeg"})

        described_class.call(album)

        expect(hq_stub).to have_been_requested
      end
    end

    context "waterfall order" do
      it "tries audio first, skips Cover Art Archive, iTunes, and YouTube when audio succeeds" do
        track = create(:track, album: album, youtube_video_id: "vid1")
        track.audio_file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )

        cover_art = {data: "fake-image-data", mime_type: "image/jpeg"}
        allow(MetadataExtractor).to receive(:call).and_return(
          {cover_art: cover_art, title: "Test"}
        )

        result = described_class.call(album)

        expect(result).to eq(:audio)
        expect(WebMock).not_to have_requested(:get, /img\.youtube\.com/)
        expect(WebMock).not_to have_requested(:get, /itunes\.apple\.com/)
      end
    end

    context "when all sources fail" do
      it "returns :not_found" do
        create(:track, album: album)

        stub_request(:get, "https://itunes.apple.com/search")
          .with(query: hash_including(entity: "album"))
          .to_return(status: 200, body: {results: []}.to_json, headers: {"Content-Type" => "application/json"})

        result = described_class.call(album)

        expect(result).to eq(:not_found)
        expect(album.cover_image).not_to be_attached
      end
    end
  end
end
