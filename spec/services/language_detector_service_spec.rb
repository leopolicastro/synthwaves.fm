require "rails_helper"

RSpec.describe LanguageDetectorService do
  describe ".call" do
    context "when track has lyrics" do
      it "detects English from lyrics" do
        track = create(:track, lyrics: "Hello world this is a song about love and happiness in the morning light")
        result = described_class.call(track)
        expect(result).to eq("en")
      end

      it "detects French from lyrics" do
        track = create(:track, lyrics: "Bonjour le monde cette chanson parle de amour et bonheur dans la lumiere du matin")
        result = described_class.call(track)
        expect(result).to eq("fr")
      end

      it "strips LRC timestamps before detection" do
        lyrics = "[00:01.00] Hello world this is a song about love and happiness\n[00:05.00] In the morning light we dance together forever"
        track = create(:track, lyrics: lyrics)
        result = described_class.call(track)
        expect(result).to eq("en")
      end

      it "returns nil for very short lyrics" do
        track = create(:track, lyrics: "Hey")
        result = described_class.call(track)
        expect(result).to be_nil
      end
    end

    context "when track has no lyrics but artist has storefront" do
      it "maps Japanese storefront to ja" do
        artist = create(:artist, apple_music_storefront: "jp")
        track = create(:track, artist: artist, lyrics: nil)
        result = described_class.call(track)
        expect(result).to eq("ja")
      end

      it "maps US storefront to en" do
        artist = create(:artist, apple_music_storefront: "us")
        track = create(:track, artist: artist, lyrics: nil)
        result = described_class.call(track)
        expect(result).to eq("en")
      end

      it "maps Korean storefront to ko" do
        artist = create(:artist, apple_music_storefront: "kr")
        track = create(:track, artist: artist, lyrics: nil)
        result = described_class.call(track)
        expect(result).to eq("ko")
      end
    end

    context "when track has no lyrics and no storefront" do
      it "returns nil" do
        track = create(:track, lyrics: nil)
        result = described_class.call(track)
        expect(result).to be_nil
      end
    end
  end
end
