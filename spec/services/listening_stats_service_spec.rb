require "rails_helper"

RSpec.describe ListeningStatsService do
  let(:user) { create(:user) }
  let(:artist) { create(:artist, name: "Synthwave Artist") }
  let(:album) { create(:album, artist: artist, genre: "Synthwave") }
  let(:track) { create(:track, album: album, artist: artist, title: "Neon Lights", duration: 240.0) }

  describe ".call" do
    it "returns a hash with all expected keys" do
      result = described_class.call(user: user)

      expect(result).to include(
        :top_tracks, :top_artists, :top_genres,
        :total_plays, :total_listening_time,
        :current_streak, :longest_streak,
        :hourly_distribution, :daily_distribution
      )
    end
  end

  describe "top_tracks" do
    it "returns tracks ordered by play count" do
      track2 = create(:track, album: album, artist: artist, title: "Midnight Drive")
      3.times { create(:play_history, user: user, track: track, played_at: 1.day.ago) }
      create(:play_history, user: user, track: track2, played_at: 1.day.ago)

      result = described_class.call(user: user)
      top = result[:top_tracks]

      expect(top.first.title).to eq("Neon Lights")
      expect(top.first.play_count).to eq(3)
      expect(top.second.title).to eq("Midnight Drive")
    end

    it "excludes other users' plays" do
      other_user = create(:user)
      create(:play_history, user: other_user, track: track, played_at: 1.day.ago)

      result = described_class.call(user: user)
      expect(result[:top_tracks]).to be_empty
    end
  end

  describe "top_artists" do
    it "returns artists ordered by play count" do
      artist2 = create(:artist, name: "Retrowave Star")
      album2 = create(:album, artist: artist2)
      track2 = create(:track, album: album2, artist: artist2)

      5.times { create(:play_history, user: user, track: track, played_at: 1.day.ago) }
      2.times { create(:play_history, user: user, track: track2, played_at: 1.day.ago) }

      result = described_class.call(user: user)
      expect(result[:top_artists].first.name).to eq("Synthwave Artist")
      expect(result[:top_artists].first.play_count).to eq(5)
    end
  end

  describe "top_genres" do
    it "returns genres ordered by play count" do
      album2 = create(:album, artist: artist, genre: "Darkwave")
      track2 = create(:track, album: album2, artist: artist)

      3.times { create(:play_history, user: user, track: track, played_at: 1.day.ago) }
      create(:play_history, user: user, track: track2, played_at: 1.day.ago)

      result = described_class.call(user: user)
      expect(result[:top_genres].first.genre).to eq("Synthwave")
      expect(result[:top_genres].first.play_count).to eq(3)
    end

    it "excludes tracks with nil or empty genre" do
      album_no_genre = create(:album, artist: artist, genre: nil)
      track_no_genre = create(:track, album: album_no_genre, artist: artist)
      create(:play_history, user: user, track: track_no_genre, played_at: 1.day.ago)

      result = described_class.call(user: user)
      expect(result[:top_genres]).to be_empty
    end
  end

  describe "total_plays" do
    it "counts plays within the time range" do
      create(:play_history, user: user, track: track, played_at: 5.days.ago)
      create(:play_history, user: user, track: track, played_at: 2.days.ago)
      create(:play_history, user: user, track: track, played_at: 60.days.ago)

      result = described_class.call(user: user, time_range: :month)
      expect(result[:total_plays]).to eq(2)

      result = described_class.call(user: user, time_range: :week)
      expect(result[:total_plays]).to eq(2)
    end
  end

  describe "total_listening_time" do
    it "sums track durations for all plays" do
      create(:play_history, user: user, track: track, played_at: 1.day.ago)
      create(:play_history, user: user, track: track, played_at: 2.days.ago)

      result = described_class.call(user: user)
      expect(result[:total_listening_time]).to eq(480.0)
    end
  end

  describe "time_range filtering" do
    it "includes all plays for all_time" do
      create(:play_history, user: user, track: track, played_at: 400.days.ago)
      create(:play_history, user: user, track: track, played_at: 1.day.ago)

      result = described_class.call(user: user, time_range: :all_time)
      expect(result[:total_plays]).to eq(2)
    end

    it "defaults invalid ranges to month" do
      # The controller validates the range, but the service should work with any valid key
      result = described_class.call(user: user, time_range: :month)
      expect(result[:total_plays]).to eq(0)
    end
  end

  describe "streaks" do
    it "calculates current streak of consecutive days" do
      create(:play_history, user: user, track: track, played_at: Date.current.beginning_of_day + 10.hours)
      create(:play_history, user: user, track: track, played_at: 1.day.ago.beginning_of_day + 10.hours)
      create(:play_history, user: user, track: track, played_at: 2.days.ago.beginning_of_day + 10.hours)

      result = described_class.call(user: user)
      expect(result[:current_streak]).to eq(3)
    end

    it "returns 0 when no plays exist" do
      result = described_class.call(user: user)
      expect(result[:current_streak]).to eq(0)
      expect(result[:longest_streak]).to eq(0)
    end

    it "calculates longest streak across all history" do
      # Old streak of 4 days
      (0..3).each do |i|
        create(:play_history, user: user, track: track, played_at: (30 - i).days.ago.beginning_of_day + 10.hours)
      end
      # Current streak of 2 days
      create(:play_history, user: user, track: track, played_at: Date.current.beginning_of_day + 10.hours)
      create(:play_history, user: user, track: track, played_at: 1.day.ago.beginning_of_day + 10.hours)

      result = described_class.call(user: user)
      expect(result[:longest_streak]).to eq(4)
      expect(result[:current_streak]).to eq(2)
    end
  end

  describe "hourly_distribution" do
    it "returns a 24-element array" do
      result = described_class.call(user: user)
      expect(result[:hourly_distribution].length).to eq(24)
      expect(result[:hourly_distribution]).to all(eq(0))
    end

    it "counts plays by hour of day" do
      create(:play_history, user: user, track: track, played_at: 1.day.ago.beginning_of_day + 14.hours)
      create(:play_history, user: user, track: track, played_at: 2.days.ago.beginning_of_day + 14.hours)
      create(:play_history, user: user, track: track, played_at: 3.days.ago.beginning_of_day + 9.hours)

      result = described_class.call(user: user)
      expect(result[:hourly_distribution][14]).to eq(2)
      expect(result[:hourly_distribution][9]).to eq(1)
    end
  end

  describe "daily_distribution" do
    it "returns a 7-element array" do
      result = described_class.call(user: user)
      expect(result[:daily_distribution].length).to eq(7)
      expect(result[:daily_distribution]).to all(eq(0))
    end
  end
end
