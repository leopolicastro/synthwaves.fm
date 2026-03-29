require "rails_helper"

RSpec.describe Maintenance::DeletePrivateVideoTracksTask do
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes tracks titled 'Private video'" do
      track = create(:track, title: "Private video")
      expect(task.collection).to include(track)
    end

    it "excludes tracks with other titles" do
      track = create(:track, title: "Neon Lights")
      expect(task.collection).not_to include(track)
    end
  end

  describe "#count" do
    it "returns the number of tracks to process" do
      create_list(:track, 3, title: "Private video")
      create(:track, title: "Neon Lights")

      expect(task.count).to eq(3)
    end
  end

  describe "#process" do
    it "destroys the track" do
      track = create(:track, title: "Private video")

      expect { task.process(track) }.to change(Track, :count).by(-1)
    end

    it "destroys associated playlist tracks" do
      track = create(:track, title: "Private video")
      create(:playlist_track, track: track)

      expect { task.process(track) }.to change(PlaylistTrack, :count).by(-1)
    end

    it "destroys associated favorites" do
      track = create(:track, title: "Private video")
      create(:favorite, favorable: track)

      expect { task.process(track) }.to change(Favorite, :count).by(-1)
    end
  end
end
