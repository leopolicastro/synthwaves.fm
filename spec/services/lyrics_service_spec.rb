require "rails_helper"

RSpec.describe LyricsService do
  let(:track) { create(:track) }
  let(:service) { described_class.new(track) }

  describe "#fetch" do
    context "when track already has lyrics" do
      it "returns stored lyrics without making an API call" do
        track.update!(lyrics: "Existing lyrics")

        result = service.fetch

        expect(result).to eq("Existing lyrics")
        expect(WebMock).not_to have_requested(:get, /lrclib/)
      end
    end

    context "when LRCLIB returns synced lyrics" do
      it "preserves timestamps for synced highlighting" do
        synced = "[00:12.34]Hello world\n[00:15.67]Second line"
        lrclib_response = [
          {
            "syncedLyrics" => synced,
            "plainLyrics" => "Hello world\nSecond line"
          }
        ].to_json

        stub_request(:get, /lrclib\.net\/api\/search/)
          .to_return(status: 200, body: lrclib_response, headers: { "Content-Type" => "application/json" })

        result = service.fetch

        expect(result).to eq(synced)
        expect(track.reload.lyrics).to eq(synced)
      end
    end

    context "when LRCLIB returns only plain lyrics" do
      it "saves plain lyrics" do
        lrclib_response = [
          {
            "syncedLyrics" => nil,
            "plainLyrics" => "Just plain lyrics\nLine two"
          }
        ].to_json

        stub_request(:get, /lrclib\.net\/api\/search/)
          .to_return(status: 200, body: lrclib_response, headers: { "Content-Type" => "application/json" })

        result = service.fetch

        expect(result).to eq("Just plain lyrics\nLine two")
        expect(track.reload.lyrics).to eq("Just plain lyrics\nLine two")
      end
    end

    context "when LRCLIB returns no results" do
      it "returns nil and does not save" do
        stub_request(:get, /lrclib\.net\/api\/search/)
          .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

        result = service.fetch

        expect(result).to be_nil
        expect(track.reload.lyrics).to be_nil
      end
    end

    context "when LRCLIB returns an error" do
      it "returns nil" do
        stub_request(:get, /lrclib\.net\/api\/search/)
          .to_return(status: 500)

        result = service.fetch

        expect(result).to be_nil
      end
    end

    context "when the network request times out" do
      it "returns nil" do
        stub_request(:get, /lrclib\.net\/api\/search/)
          .to_timeout

        result = service.fetch

        expect(result).to be_nil
      end
    end
  end

  describe "query building" do
    it "cleans noise from titles" do
      track = create(:track, title: "Song Name (Official Video) [Remastered]")
      service = described_class.new(track)

      stub_request(:get, /lrclib\.net\/api\/search/)
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      service.fetch

      expect(WebMock).to have_requested(:get, /lrclib\.net\/api\/search/)
        .with(query: hash_including("q" => /Song Name/))
      expect(WebMock).not_to have_requested(:get, /lrclib\.net\/api\/search/)
        .with(query: hash_including("q" => /Official/))
    end
  end
end
