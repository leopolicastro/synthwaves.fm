require "rails_helper"

RSpec.describe Artist, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:albums).dependent(:destroy) }
    it { should have_many(:tracks).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:artist) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  describe "category" do
    it "defaults to music" do
      artist = Artist.new(name: "Test")
      expect(artist.category).to eq("music")
      expect(artist).to be_music
    end

    it "can be set to podcast" do
      artist = create(:artist, :podcast)
      expect(artist).to be_podcast
      expect(artist).not_to be_music
    end

    it "validates category inclusion" do
      artist = build(:artist)
      expect { artist.category = "invalid" }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    let!(:music_artist) { create(:artist, category: "music") }
    let!(:podcast_artist) { create(:artist, :podcast) }

    it ".music returns only music artists" do
      expect(Artist.music).to include(music_artist)
      expect(Artist.music).not_to include(podcast_artist)
    end

    it ".podcast returns only podcast artists" do
      expect(Artist.podcast).to include(podcast_artist)
      expect(Artist.podcast).not_to include(music_artist)
    end

    describe ".search" do
      let!(:artist1) { create(:artist, name: "Pink Floyd") }
      let!(:artist2) { create(:artist, name: "Led Zeppelin") }

      it "returns artists matching the query" do
        results = Artist.search("Pink")
        expect(results).to include(artist1)
        expect(results).not_to include(artist2)
      end

      it "is case-insensitive" do
        results = Artist.search("pink")
        expect(results).to include(artist1)
      end

      it "returns no results when nothing matches" do
        results = Artist.search("Nonexistent")
        expect(results).to be_empty
      end

      it "returns all artists when query is blank" do
        results = Artist.search("")
        expect(results).to include(artist1, artist2)
      end

      it "returns all artists when query is nil" do
        results = Artist.search(nil)
        expect(results).to include(artist1, artist2)
      end
    end
  end
end
