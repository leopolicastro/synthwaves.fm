require "rails_helper"

RSpec.describe EPGProgramme, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:ends_at) }
  end

  describe "scopes" do
    describe ".for_channel" do
      it "returns programmes for the given channel" do
        prog = create(:epg_programme, channel_id: "espn.us")
        _other = create(:epg_programme, channel_id: "cnn.us")

        expect(described_class.for_channel("espn.us")).to eq([prog])
      end
    end

    describe ".current" do
      it "returns programmes airing now" do
        current = create(:epg_programme, :current)
        _expired = create(:epg_programme, :expired)
        _upcoming = create(:epg_programme, :upcoming)

        expect(described_class.current).to eq([current])
      end
    end

    describe ".upcoming" do
      it "returns future programmes ordered by start time" do
        later = create(:epg_programme, :upcoming, starts_at: 3.hours.from_now, ends_at: 4.hours.from_now)
        sooner = create(:epg_programme, :upcoming, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        _current = create(:epg_programme, :current)

        expect(described_class.upcoming).to eq([sooner, later])
      end
    end

    describe ".expired" do
      it "returns programmes that have ended" do
        expired = create(:epg_programme, :expired)
        _current = create(:epg_programme, :current)

        expect(described_class.expired).to eq([expired])
      end
    end

    describe ".in_window" do
      it "returns programmes overlapping the given time window" do
        overlapping = create(:epg_programme, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        _outside = create(:epg_programme, starts_at: 5.hours.from_now, ends_at: 6.hours.from_now)

        window_start = 30.minutes.ago
        window_end = 30.minutes.from_now

        expect(described_class.in_window(window_start, window_end)).to eq([overlapping])
      end

      it "includes programmes that start before and end after the window" do
        spanning = create(:epg_programme, starts_at: 2.hours.ago, ends_at: 2.hours.from_now)

        expect(described_class.in_window(30.minutes.ago, 30.minutes.from_now)).to eq([spanning])
      end

      it "includes programmes that start within the window" do
        starting = create(:epg_programme, starts_at: 10.minutes.from_now, ends_at: 2.hours.from_now)

        expect(described_class.in_window(Time.current, 1.hour.from_now)).to eq([starting])
      end
    end
  end

  describe ".now_playing" do
    it "returns the current programme for a channel" do
      prog = create(:epg_programme, :current, channel_id: "espn.us")
      _other = create(:epg_programme, :current, channel_id: "cnn.us")

      expect(described_class.now_playing("espn.us")).to eq(prog)
    end

    it "returns nil when nothing is airing" do
      create(:epg_programme, :expired, channel_id: "espn.us")

      expect(described_class.now_playing("espn.us")).to be_nil
    end
  end

  describe ".up_next" do
    it "returns upcoming programmes for a channel" do
      channel_id = "espn.us"
      next1 = create(:epg_programme, channel_id: channel_id, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
      next2 = create(:epg_programme, channel_id: channel_id, starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
      _other_channel = create(:epg_programme, :upcoming, channel_id: "cnn.us")

      expect(described_class.up_next(channel_id, limit: 2)).to eq([next1, next2])
    end

    it "respects the limit" do
      channel_id = "espn.us"
      create(:epg_programme, channel_id: channel_id, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
      create(:epg_programme, channel_id: channel_id, starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
      create(:epg_programme, channel_id: channel_id, starts_at: 3.hours.from_now, ends_at: 4.hours.from_now)

      expect(described_class.up_next(channel_id, limit: 1).size).to eq(1)
    end
  end

  describe "#live?" do
    it "returns true for a currently airing programme" do
      programme = build(:epg_programme, :current)
      expect(programme).to be_live
    end

    it "returns false for an expired programme" do
      programme = build(:epg_programme, :expired)
      expect(programme).not_to be_live
    end

    it "returns false for an upcoming programme" do
      programme = build(:epg_programme, :upcoming)
      expect(programme).not_to be_live
    end
  end

  describe "#progress_percentage" do
    it "returns the percentage of the programme elapsed" do
      freeze_time do
        programme = build(:epg_programme, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
        expect(programme.progress_percentage).to eq(50)
      end
    end

    it "returns 0 for upcoming programmes" do
      programme = build(:epg_programme, :upcoming)
      expect(programme.progress_percentage).to eq(0)
    end

    it "returns 0 for expired programmes" do
      programme = build(:epg_programme, :expired)
      expect(programme.progress_percentage).to eq(0)
    end
  end

  describe "#remaining_minutes" do
    it "returns minutes remaining for a live programme" do
      freeze_time do
        programme = build(:epg_programme, starts_at: 30.minutes.ago, ends_at: 45.minutes.from_now)
        expect(programme.remaining_minutes).to eq(45)
      end
    end

    it "returns 0 for expired programmes" do
      programme = build(:epg_programme, :expired)
      expect(programme.remaining_minutes).to eq(0)
    end

    it "returns 0 for upcoming programmes" do
      programme = build(:epg_programme, :upcoming)
      expect(programme.remaining_minutes).to eq(0)
    end
  end
end
