require "rails_helper"

RSpec.describe Maintenance::DeleteEmptyArtistsTask do
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes artists with no albums and no tracks" do
      artist = create(:artist)
      expect(task.collection).to include(artist)
    end

    it "excludes artists that have albums" do
      artist = create(:artist)
      create(:album, artist: artist)
      expect(task.collection).not_to include(artist)
    end

    it "excludes artists that have tracks" do
      artist = create(:artist)
      album = create(:album)
      create(:track, artist: artist, album: album)
      expect(task.collection).not_to include(artist)
    end
  end

  describe "#count" do
    it "returns the number of empty artists" do
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
  end
end
