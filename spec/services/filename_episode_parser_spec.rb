require "rails_helper"

RSpec.describe FilenameEpisodeParser do
  describe ".parse" do
    it "parses S01E03 format" do
      result = described_class.parse("S01E03 - The Title.mkv")

      expect(result.season_number).to eq(1)
      expect(result.episode_number).to eq(3)
      expect(result.title).to eq("The Title")
    end

    it "parses s01e03 lowercase format" do
      result = described_class.parse("s02e10.mp4")

      expect(result.season_number).to eq(2)
      expect(result.episode_number).to eq(10)
    end

    it "parses 1x03 format" do
      result = described_class.parse("1x03 - The Title.mkv")

      expect(result.season_number).to eq(1)
      expect(result.episode_number).to eq(3)
      expect(result.title).to eq("The Title")
    end

    it "parses E03 format with default season" do
      result = described_class.parse("E03 - The Title.mkv", default_season: 2)

      expect(result.season_number).to eq(2)
      expect(result.episode_number).to eq(3)
      expect(result.title).to eq("The Title")
    end

    it "parses E03 format without default season" do
      result = described_class.parse("E03 - The Title.mkv")

      expect(result.season_number).to be_nil
      expect(result.episode_number).to eq(3)
      expect(result.title).to eq("The Title")
    end

    it "parses leading number format (03 - Title)" do
      result = described_class.parse("03 - The Title.mkv", default_season: 1)

      expect(result.season_number).to eq(1)
      expect(result.episode_number).to eq(3)
      expect(result.title).to eq("The Title")
    end

    it "returns no episode info for plain titles" do
      result = described_class.parse("The Title.mkv")

      expect(result.season_number).to be_nil
      expect(result.episode_number).to be_nil
      expect(result.title).to eq("The Title")
    end

    it "uses default_season for plain titles" do
      result = described_class.parse("The Title.mkv", default_season: 3)

      expect(result.season_number).to eq(3)
      expect(result.episode_number).to be_nil
      expect(result.title).to eq("The Title")
    end

    it "strips file extension" do
      result = described_class.parse("S01E01 - Pilot.mp4")

      expect(result.title).to eq("Pilot")
    end

    it "handles filenames with dots as separators" do
      result = described_class.parse("S01E05.The.Title.mp4")

      expect(result.season_number).to eq(1)
      expect(result.episode_number).to eq(5)
      expect(result.title).to eq("The.Title")
    end

    it "handles multi-digit episode numbers" do
      result = described_class.parse("S01E123.mp4")

      expect(result.season_number).to eq(1)
      expect(result.episode_number).to eq(123)
    end
  end
end
