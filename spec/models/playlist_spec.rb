require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:playlist_tracks).dependent(:destroy) }
    it { should have_many(:tracks).through(:playlist_tracks) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe ".search" do
    let(:user) { create(:user) }
    let!(:chill) { create(:playlist, user: user, name: "Chill Vibes") }
    let!(:rock) { create(:playlist, user: user, name: "Rock Anthems") }
    let!(:chill_rock) { create(:playlist, user: user, name: "Chill Rock Mix") }

    it "returns all playlists when query is nil" do
      expect(Playlist.search(nil)).to contain_exactly(chill, rock, chill_rock)
    end

    it "returns all playlists when query is blank" do
      expect(Playlist.search("")).to contain_exactly(chill, rock, chill_rock)
    end

    it "filters playlists by name" do
      expect(Playlist.search("Chill")).to contain_exactly(chill, chill_rock)
    end

    it "is case-insensitive" do
      expect(Playlist.search("chill")).to contain_exactly(chill, chill_rock)
    end

    it "returns empty when no match" do
      expect(Playlist.search("Jazz")).to be_empty
    end
  end
end
