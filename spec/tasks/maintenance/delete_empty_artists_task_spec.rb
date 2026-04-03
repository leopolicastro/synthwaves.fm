require "rails_helper"

RSpec.describe Maintenance::DeleteEmptyArtistsTask do
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes artists with no albums" do
      artist = create(:artist)
      expect(task.collection).to include(artist)
    end

    it "includes artists with no albums but with tracks in other artists' albums" do
      artist = create(:artist)
      album = create(:album)
      create(:track, artist: artist, album: album)
      expect(task.collection).to include(artist)
    end

    it "excludes artists that have albums" do
      artist = create(:artist)
      create(:album, artist: artist)
      expect(task.collection).not_to include(artist)
    end
  end

  describe "#count" do
    it "returns the number of artists without albums" do
      create_list(:artist, 2)
      artist_with_album = create(:artist)
      create(:album, artist: artist_with_album)

      expect(task.count).to eq(2)
    end
  end

  describe "#process" do
    it "destroys the artist" do
      artist = create(:artist)

      expect { task.process(artist) }.to change(Artist, :count).by(-1)
    end

    it "reassigns orphaned tracks to their album's artist before destroying" do
      orphan_artist = create(:artist)
      album_owner = create(:artist)
      album = create(:album, artist: album_owner)
      track = create(:track, artist: orphan_artist, album: album)

      task.process(orphan_artist)

      expect(track.reload.artist).to eq(album_owner)
      expect(Artist.exists?(orphan_artist.id)).to be false
    end

    it "does not delete any tracks" do
      orphan_artist = create(:artist)
      album = create(:album)
      create(:track, artist: orphan_artist, album: album)

      expect { task.process(orphan_artist) }.not_to change(Track, :count)
    end
  end
end
