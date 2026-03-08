require "rails_helper"

RSpec.describe TracksHelper, type: :helper do
  describe "#format_duration" do
    it "returns '0:00' for nil" do
      expect(helper.format_duration(nil)).to eq("0:00")
    end

    it "returns '0:00' for zero" do
      expect(helper.format_duration(0)).to eq("0:00")
    end

    it "returns '0:00' for negative values" do
      expect(helper.format_duration(-5)).to eq("0:00")
    end

    it "formats seconds under a minute" do
      expect(helper.format_duration(45)).to eq("0:45")
    end

    it "zero-pads seconds" do
      expect(helper.format_duration(62)).to eq("1:02")
    end

    it "formats minutes and seconds" do
      expect(helper.format_duration(185)).to eq("3:05")
    end

    it "formats hours when 60 minutes or more" do
      expect(helper.format_duration(3661)).to eq("1:01:01")
    end

    it "zero-pads minutes and seconds in hour format" do
      expect(helper.format_duration(3600)).to eq("1:00:00")
    end

    it "handles exactly 60 minutes" do
      expect(helper.format_duration(3600)).to eq("1:00:00")
    end

    it "handles multi-hour durations" do
      expect(helper.format_duration(7384)).to eq("2:03:04")
    end
  end
end
