require "rails_helper"

RSpec.describe AiDjService do
  let(:user) { create(:user) }

  describe ".call" do
    it "returns a string prompt" do
      result = described_class.call(user: user)
      expect(result).to be_a(String)
    end

    it "includes the DJ persona" do
      result = described_class.call(user: user)
      expect(result).to include("DJ Synth")
    end

    it "requests 8-10 recommendations" do
      result = described_class.call(user: user)
      expect(result).to include("8-10 track recommendations")
    end

    context "with listening history" do
      let(:artist) { create(:artist, name: "The Midnight") }
      let(:album) { create(:album, artist: artist, genre: "Synthwave") }
      let(:track) { create(:track, album: album, artist: artist, title: "Los Angeles") }

      before do
        5.times { create(:play_history, user: user, track: track) }
      end

      it "includes top artists" do
        result = described_class.call(user: user)
        expect(result).to include("The Midnight")
        expect(result).to include("Top Artists")
      end

      it "includes top tracks" do
        result = described_class.call(user: user)
        expect(result).to include("Los Angeles")
        expect(result).to include("Top Tracks")
      end

      it "includes top genres" do
        result = described_class.call(user: user)
        expect(result).to include("Synthwave")
        expect(result).to include("Top Genres")
      end
    end

    context "with library artists" do
      before do
        create(:artist, name: "FM-84")
        create(:artist, name: "Gunship")
      end

      it "includes available library artists" do
        result = described_class.call(user: user)
        expect(result).to include("FM-84")
        expect(result).to include("Gunship")
        expect(result).to include("Available in their library")
      end
    end

    context "without any data" do
      it "still generates a valid prompt" do
        result = described_class.call(user: user)
        expect(result).to include("DJ Synth")
        expect(result).to include("8-10 track recommendations")
      end

      it "does not include listening context sections" do
        result = described_class.call(user: user)
        expect(result).not_to include("Top Artists")
      end
    end
  end
end
