require "rails_helper"

RSpec.describe Album, type: :model do
  describe "associations" do
    it { should belong_to(:artist) }
    it { should have_many(:tracks).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
    it { should have_one_attached(:cover_image) }
  end

  describe "validations" do
    subject { build(:album) }

    it { should validate_presence_of(:title) }
    it { should validate_uniqueness_of(:title).scoped_to(:artist_id) }
  end

  describe ".search" do
    let!(:abbey_road) { create(:album, title: "Abbey Road") }
    let!(:dark_side) { create(:album, title: "Dark Side of the Moon") }

    it "returns albums matching the query" do
      expect(Album.search("Abbey")).to include(abbey_road)
      expect(Album.search("Abbey")).not_to include(dark_side)
    end

    it "returns no albums when nothing matches" do
      expect(Album.search("Nonexistent")).to be_empty
    end

    it "returns all albums when query is blank" do
      expect(Album.search("")).to include(abbey_road, dark_side)
      expect(Album.search(nil)).to include(abbey_road, dark_side)
    end
  end

  describe ".with_streamable_tracks" do
    it "includes albums that have at least one streamable track" do
      album = create(:album)
      create(:track, album: album, artist: album.artist)

      expect(Album.with_streamable_tracks).to include(album)
    end

    it "excludes albums where all tracks are YouTube-only" do
      album = create(:album)
      create(:track, :youtube, album: album, artist: album.artist)

      expect(Album.with_streamable_tracks).not_to include(album)
    end

    it "includes albums with a mix of streamable and YouTube tracks" do
      album = create(:album)
      create(:track, album: album, artist: album.artist)
      create(:track, :youtube, album: album, artist: album.artist)

      expect(Album.with_streamable_tracks).to include(album)
    end

    it "excludes albums with no tracks" do
      album = create(:album)

      expect(Album.with_streamable_tracks).not_to include(album)
    end
  end

  describe "category scopes" do
    let!(:music_album) { create(:album, artist: create(:artist, category: "music")) }
    let!(:podcast_album) { create(:album, artist: create(:artist, :podcast)) }

    it ".music returns only albums belonging to music artists" do
      expect(Album.music).to include(music_album)
      expect(Album.music).not_to include(podcast_album)
    end

    it ".podcast returns only albums belonging to podcast artists" do
      expect(Album.podcast).to include(podcast_album)
      expect(Album.podcast).not_to include(music_album)
    end
  end
end
