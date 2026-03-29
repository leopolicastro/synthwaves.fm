require "rails_helper"

RSpec.describe StatsHelper, type: :helper do
  describe "#format_listening_time" do
    it "returns '0m' for nil" do
      expect(helper.format_listening_time(nil)).to eq("0m")
    end

    it "returns '0m' for zero" do
      expect(helper.format_listening_time(0)).to eq("0m")
    end

    it "returns '0m' for negative values" do
      expect(helper.format_listening_time(-100)).to eq("0m")
    end

    it "formats minutes only when under an hour" do
      expect(helper.format_listening_time(300)).to eq("5m")
    end

    it "formats hours and minutes" do
      expect(helper.format_listening_time(3720)).to eq("1h 2m")
    end

    it "formats exact hours with 0 minutes" do
      expect(helper.format_listening_time(3600)).to eq("1h 0m")
    end

    it "formats multiple hours" do
      expect(helper.format_listening_time(7260)).to eq("2h 1m")
    end

    it "handles partial minutes (rounds down)" do
      expect(helper.format_listening_time(90)).to eq("1m")
    end

    it "handles less than a minute" do
      expect(helper.format_listening_time(30)).to eq("0m")
    end
  end

  describe "#format_library_duration" do
    it "returns '0m' for nil" do
      expect(helper.format_library_duration(nil)).to eq("0m")
    end

    it "returns '0m' for zero" do
      expect(helper.format_library_duration(0)).to eq("0m")
    end

    it "returns '0m' for negative values" do
      expect(helper.format_library_duration(-100)).to eq("0m")
    end

    it "falls back to format_listening_time for sub-day durations" do
      expect(helper.format_library_duration(7260)).to eq("2h 1m")
    end

    it "formats days and hours for large durations" do
      expect(helper.format_library_duration(90_000)).to eq("1d 1h")
    end

    it "formats multiple days" do
      expect(helper.format_library_duration(1_209_600)).to eq("14d 0h")
    end

    it "handles exact day boundaries" do
      expect(helper.format_library_duration(86_400)).to eq("1d 0h")
    end
  end
end
