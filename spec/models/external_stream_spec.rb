require "rails_helper"

RSpec.describe ExternalStream, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:source_type).in_array(%w[youtube stream]) }

    context "youtube station" do
      subject { build(:external_stream, source_type: "youtube") }

      it { is_expected.to validate_presence_of(:youtube_url) }

      it "rejects a playlist URL with a helpful message" do
        station = build(:external_stream, youtube_url: "https://music.youtube.com/playlist?list=OLAK5uy_abc", youtube_video_id: nil)
        station.valid?
        expect(station.errors[:youtube_url].first).to include("playlist URL")
        expect(station.errors[:youtube_url].first).to include("Import from YouTube")
      end

      it "rejects a non-YouTube URL" do
        station = build(:external_stream, youtube_url: "https://example.com", youtube_video_id: nil)
        station.valid?
        expect(station.errors[:youtube_url].first).to include("doesn't appear to be a valid")
      end

      it "does not require stream_url" do
        station = build(:external_stream, source_type: "youtube", stream_url: nil)
        station.valid?
        expect(station.errors[:stream_url]).to be_empty
      end
    end

    context "stream station" do
      subject { build(:external_stream, :stream) }

      it { is_expected.to validate_presence_of(:stream_url) }

      it "does not require youtube_url" do
        station = build(:external_stream, :stream, youtube_url: nil)
        station.valid?
        expect(station.errors[:youtube_url]).to be_empty
      end

      it "is valid with a stream_url and no youtube fields" do
        station = build(:external_stream, :stream)
        expect(station).to be_valid
      end
    end
  end

  describe "before_validation" do
    it "extracts video ID from youtube_url when youtube_video_id is blank" do
      station = build(:external_stream, youtube_url: "https://www.youtube.com/watch?v=jfKfPfyJRdk", youtube_video_id: nil)
      station.valid?
      expect(station.youtube_video_id).to eq("jfKfPfyJRdk")
    end

    it "does not overwrite an existing youtube_video_id" do
      station = build(:external_stream, youtube_url: "https://www.youtube.com/watch?v=jfKfPfyJRdk", youtube_video_id: "existing123")
      station.valid?
      expect(station.youtube_video_id).to eq("existing123")
    end

    it "does not extract video ID for stream stations" do
      station = build(:external_stream, :stream)
      station.valid?
      expect(station.youtube_video_id).to be_nil
    end
  end

  describe "#youtube?" do
    it "returns true for youtube source_type" do
      expect(build(:external_stream, source_type: "youtube")).to be_youtube
    end

    it "returns false for stream source_type" do
      expect(build(:external_stream, :stream)).not_to be_youtube
    end
  end

  describe "#stream?" do
    it "returns true for stream source_type" do
      expect(build(:external_stream, :stream)).to be_stream
    end

    it "returns false for youtube source_type" do
      expect(build(:external_stream, source_type: "youtube")).not_to be_stream
    end
  end
end
