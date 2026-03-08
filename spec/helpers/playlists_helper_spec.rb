require "rails_helper"

RSpec.describe PlaylistsHelper, type: :helper do
  describe "#playlist_tracks_as_text" do
    it "formats a regular track as 'Artist - Title'" do
      pt = create(:playlist_track)
      track = pt.track

      result = helper.playlist_tracks_as_text([pt])

      expect(result).to eq("#{track.artist.name} - #{track.title}")
    end

    it "appends YouTube URL for YouTube tracks" do
      track = create(:track, youtube_video_id: "dQw4w9WgXcQ")
      pt = create(:playlist_track, track: track)

      result = helper.playlist_tracks_as_text([pt])

      expect(result).to eq("#{track.artist.name} - #{track.title} | https://youtube.com/watch?v=dQw4w9WgXcQ")
    end

    it "joins multiple tracks with newlines" do
      pt1 = create(:playlist_track)
      pt2 = create(:playlist_track)

      result = helper.playlist_tracks_as_text([pt1, pt2])

      expect(result).to include("\n")
      expect(result.lines.count).to eq(2)
    end

    it "returns empty string for empty list" do
      result = helper.playlist_tracks_as_text([])

      expect(result).to eq("")
    end
  end
end
