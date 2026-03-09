require "rails_helper"

RSpec.describe Recording, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:iptv_channel) }
    it { is_expected.to belong_to(:epg_programme).optional }
    it { is_expected.to have_many(:user_recordings).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:user_recordings) }
  end

  describe "validations" do
    it "is valid with valid attributes" do
      recording = build(:recording)
      expect(recording).to be_valid
    end

    it "validates title presence" do
      recording = build(:recording, title: nil)
      expect(recording).not_to be_valid
      expect(recording.errors[:title]).to be_present
    end

    it "validates status inclusion" do
      recording = build(:recording, status: "unknown")
      expect(recording).not_to be_valid
      expect(recording.errors[:status]).to be_present
    end

    it "validates ends_at is after starts_at" do
      recording = build(:recording, starts_at: 1.hour.from_now, ends_at: 30.minutes.from_now)
      expect(recording).not_to be_valid
      expect(recording.errors[:ends_at]).to be_present
    end

    it "validates max 4-hour duration" do
      recording = build(:recording, starts_at: Time.current, ends_at: 5.hours.from_now)
      expect(recording).not_to be_valid
      expect(recording.errors[:base]).to include("Recording cannot exceed 4 hours")
    end

    it "allows up to 4-hour duration" do
      now = Time.current
      recording = build(:recording, starts_at: now, ends_at: now + 4.hours)
      expect(recording).to be_valid
    end
  end

  describe "scopes" do
    describe ".upcoming" do
      it "returns scheduled recordings with future start times" do
        upcoming = create(:recording, status: "scheduled", starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        past_scheduled = create(:recording, status: "scheduled", starts_at: 1.hour.ago, ends_at: 30.minutes.from_now)
        recording_now = create(:recording, :recording_now)

        result = Recording.upcoming
        expect(result).to include(upcoming)
        expect(result).not_to include(past_scheduled)
        expect(result).not_to include(recording_now)
      end
    end

    describe ".active" do
      it "returns scheduled, recording, and processing recordings" do
        scheduled = create(:recording)
        recording = create(:recording, :recording_now)
        processing = create(:recording, :processing)
        ready = create(:recording, :ready)
        failed = create(:recording, :failed)

        result = Recording.active
        expect(result).to include(scheduled, recording, processing)
        expect(result).not_to include(ready, failed)
      end
    end

    describe ".search" do
      it "matches by title" do
        match = create(:recording, title: "Evening News")
        no_match = create(:recording, title: "Morning Show")

        result = Recording.search("News")
        expect(result).to include(match)
        expect(result).not_to include(no_match)
      end

      it "matches by channel name" do
        channel = create(:iptv_channel, name: "BBC One")
        match = create(:recording, iptv_channel: channel)
        no_match = create(:recording, title: "Other Show")

        result = Recording.search("BBC")
        expect(result).to include(match)
        expect(result).not_to include(no_match)
      end

      it "returns all when blank" do
        recording = create(:recording)
        expect(Recording.search("")).to include(recording)
        expect(Recording.search(nil)).to include(recording)
      end
    end

    describe ".by_status" do
      it "filters by status" do
        scheduled = create(:recording, status: "scheduled")
        ready = create(:recording, :ready)

        result = Recording.by_status("scheduled")
        expect(result).to include(scheduled)
        expect(result).not_to include(ready)
      end

      it "returns all when blank" do
        scheduled = create(:recording, status: "scheduled")
        ready = create(:recording, :ready)

        result = Recording.by_status("")
        expect(result).to include(scheduled, ready)
      end

      it "returns all when invalid" do
        recording = create(:recording)

        result = Recording.by_status("bogus")
        expect(result).to include(recording)
      end
    end

    describe ".completed" do
      it "returns ready recordings ordered by created_at desc" do
        old_ready = create(:recording, :ready, created_at: 2.days.ago)
        new_ready = create(:recording, :ready, created_at: 1.day.ago)
        failed = create(:recording, :failed)

        result = Recording.completed
        expect(result).to eq([new_ready, old_ready])
        expect(result).not_to include(failed)
      end
    end
  end

  describe "status predicates" do
    it "returns true for scheduled?" do
      expect(build(:recording, status: "scheduled")).to be_scheduled
    end

    it "returns true for recording?" do
      expect(build(:recording, status: "recording")).to be_recording
    end

    it "returns true for processing?" do
      expect(build(:recording, status: "processing")).to be_processing
    end

    it "returns true for ready?" do
      expect(build(:recording, status: "ready")).to be_ready
    end

    it "returns true for failed?" do
      expect(build(:recording, status: "failed")).to be_failed
    end

    it "returns true for cancelled?" do
      expect(build(:recording, status: "cancelled")).to be_cancelled
    end
  end

  describe "#cancellable?" do
    it "is cancellable when scheduled" do
      expect(build(:recording, status: "scheduled")).to be_cancellable
    end

    it "is cancellable when recording" do
      expect(build(:recording, status: "recording")).to be_cancellable
    end

    it "is not cancellable when ready" do
      expect(build(:recording, status: "ready")).not_to be_cancellable
    end

    it "is not cancellable when failed" do
      expect(build(:recording, status: "failed")).not_to be_cancellable
    end

    it "is not cancellable when cancelled" do
      expect(build(:recording, status: "cancelled")).not_to be_cancellable
    end
  end

  describe "#filename" do
    it "generates sanitized mp4 filename from title" do
      recording = build(:recording, title: "News @ 10 (Live)")
      expect(recording.filename).to eq("News 10 Live.mp4")
    end
  end

  describe "#broadcast_status" do
    it "broadcasts to all subscribed users" do
      recording = create(:recording)
      user1 = create(:user)
      user2 = create(:user)
      create(:user_recording, user: user1, recording: recording)
      create(:user_recording, user: user2, recording: recording)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "recordings_#{user1.id}", hash_including(target: "recording_#{recording.id}")
      )
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "recordings_#{user2.id}", hash_including(target: "recording_#{recording.id}")
      )

      recording.broadcast_status
    end
  end
end
