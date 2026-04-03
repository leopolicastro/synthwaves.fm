require "rails_helper"

RSpec.describe Maintenance::DeleteEmptyAlbumsTask do
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes albums with no tracks" do
      album = create(:album)
      expect(task.collection).to include(album)
    end

    it "excludes albums that have tracks" do
      album = create(:album)
      create(:track, album: album, artist: album.artist)
      expect(task.collection).not_to include(album)
    end
  end

  describe "#count" do
    it "returns the number of empty albums" do
      create_list(:album, 2)
      album_with_tracks = create(:album)
      create(:track, album: album_with_tracks, artist: album_with_tracks.artist)

      expect(task.count).to eq(2)
    end
  end

  describe "#process" do
    it "destroys the album" do
      album = create(:album)

      expect { task.process(album) }.to change(Album, :count).by(-1)
    end
  end
end
