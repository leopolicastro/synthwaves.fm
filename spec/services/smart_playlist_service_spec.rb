require "rails_helper"

RSpec.describe SmartPlaylistService do
  let(:user) { create(:user) }
  let(:artist) { create(:artist) }
  let(:album) { create(:album, artist: artist) }

  describe ".all_definitions" do
    it "returns all playlist definitions" do
      expect(described_class.all_definitions.keys).to contain_exactly(
        :most_played, :recently_added, :unplayed, :heavy_rotation, :deep_cuts
      )
    end
  end

  describe "most_played" do
    it "returns tracks ordered by play count" do
      track1 = create(:track, album: album, artist: artist, title: "Hit Song")
      track2 = create(:track, album: album, artist: artist, title: "One-Hit Wonder")

      5.times { create(:play_history, user: user, track: track1) }
      create(:play_history, user: user, track: track2)

      result = described_class.call(user: user, playlist_id: :most_played)
      expect(result.first.title).to eq("Hit Song")
    end

    it "excludes podcast tracks" do
      podcast_artist = create(:artist, :podcast)
      podcast_album = create(:album, artist: podcast_artist)
      podcast_track = create(:track, album: podcast_album, artist: podcast_artist)
      create(:play_history, user: user, track: podcast_track)

      result = described_class.call(user: user, playlist_id: :most_played)
      expect(result).to be_empty
    end

    it "only includes the current user's plays" do
      other_user = create(:user)
      track = create(:track, album: album, artist: artist)
      create(:play_history, user: other_user, track: track)

      result = described_class.call(user: user, playlist_id: :most_played)
      expect(result).to be_empty
    end
  end

  describe "recently_added" do
    it "returns tracks added within the last 30 days" do
      recent = create(:track, album: album, artist: artist, created_at: 5.days.ago)
      create(:track, album: album, artist: artist, created_at: 60.days.ago)

      result = described_class.call(user: user, playlist_id: :recently_added)
      expect(result.map(&:id)).to eq([recent.id])
    end
  end

  describe "unplayed" do
    it "returns tracks the user has never played" do
      played = create(:track, album: album, artist: artist)
      unplayed = create(:track, album: album, artist: artist)
      create(:play_history, user: user, track: played)

      result = described_class.call(user: user, playlist_id: :unplayed)
      expect(result.map(&:id)).to include(unplayed.id)
      expect(result.map(&:id)).not_to include(played.id)
    end

    it "includes tracks played by other users but not the current user" do
      other_user = create(:user)
      track = create(:track, album: album, artist: artist)
      create(:play_history, user: other_user, track: track)

      result = described_class.call(user: user, playlist_id: :unplayed)
      expect(result.map(&:id)).to include(track.id)
    end
  end

  describe "heavy_rotation" do
    it "returns tracks played 3+ times in the last 2 weeks" do
      hot_track = create(:track, album: album, artist: artist)
      cold_track = create(:track, album: album, artist: artist)

      4.times { create(:play_history, user: user, track: hot_track, played_at: 1.week.ago) }
      create(:play_history, user: user, track: cold_track, played_at: 1.week.ago)

      result = described_class.call(user: user, playlist_id: :heavy_rotation)
      expect(result.map(&:id)).to include(hot_track.id)
      expect(result.map(&:id)).not_to include(cold_track.id)
    end

    it "excludes plays older than 2 weeks" do
      track = create(:track, album: album, artist: artist)
      5.times { create(:play_history, user: user, track: track, played_at: 3.weeks.ago) }

      result = described_class.call(user: user, playlist_id: :heavy_rotation)
      expect(result).to be_empty
    end
  end

  describe "deep_cuts" do
    it "returns tracks played only once or twice" do
      deep = create(:track, album: album, artist: artist)
      popular = create(:track, album: album, artist: artist)

      2.times { create(:play_history, user: user, track: deep) }
      10.times { create(:play_history, user: user, track: popular) }

      result = described_class.call(user: user, playlist_id: :deep_cuts)
      expect(result.map(&:id)).to include(deep.id)
      expect(result.map(&:id)).not_to include(popular.id)
    end
  end

  describe "invalid playlist_id" do
    it "returns an empty relation" do
      result = described_class.call(user: user, playlist_id: :nonexistent)
      expect(result).to be_empty
    end
  end
end
