require "rails_helper"

RSpec.describe YoutubePlaylistImportService do
  let(:api_key) { "test_api_key" }
  let(:user) { create(:user) }

  describe ".call" do
    it "raises error for invalid playlist URL" do
      expect { described_class.call("https://www.youtube.com/watch?v=abc", api_key: api_key, user: user) }
        .to raise_error(YoutubePlaylistImportService::Error, "Invalid YouTube playlist URL")
    end

    it "imports a playlist as an album with tracks" do
      stub_playlist_api_calls

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album).to be_persisted
      expect(album.title).to eq("Test Playlist")
      expect(album.artist.name).to eq("Test Channel")
      expect(album.tracks.count).to eq(2)

      track1 = album.tracks.find_by(youtube_video_id: "vid1")
      expect(track1.title).to eq("Song 1")
      expect(track1.track_number).to eq(1)
      expect(track1.duration).to eq(225.0)

      track2 = album.tracks.find_by(youtube_video_id: "vid2")
      expect(track2.title).to eq("Song 2")
      expect(track2.track_number).to eq(2)
    end

    it "skips duplicate tracks on re-import" do
      stub_playlist_api_calls

      described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)
      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album.tracks.count).to eq(2)
      expect(Track.where(youtube_video_id: "vid1").count).to eq(1)
    end

    it "creates a music artist by default" do
      stub_playlist_api_calls

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album.artist).to be_music
    end

    it "creates a podcast artist when category is podcast" do
      stub_playlist_api_calls

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", category: "podcast", api_key: api_key, user: user)

      expect(album.artist).to be_podcast
    end

    it "saves youtube_playlist_url on the album" do
      stub_playlist_api_calls

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album.youtube_playlist_url).to eq("https://www.youtube.com/playlist?list=PLtest123")
    end

    it "does not overwrite existing youtube_playlist_url on re-import" do
      stub_playlist_api_calls

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)
      album.update!(youtube_playlist_url: "https://www.youtube.com/playlist?list=PLoriginal")

      described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)
      album.reload

      expect(album.youtube_playlist_url).to eq("https://www.youtube.com/playlist?list=PLoriginal")
    end

    it "does not overwrite existing artist category on re-import" do
      stub_playlist_api_calls

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", category: "music", api_key: api_key, user: user)
      expect(album.artist).to be_music

      album2 = described_class.call("https://www.youtube.com/playlist?list=PLtest123", category: "podcast", api_key: api_key, user: user)
      expect(album2.artist).to be_music
    end

    it "downloads and attaches the thumbnail" do
      stub_playlist_api_calls
      stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
        .to_return(status: 200, body: "fake_image_data", headers: { "Content-Type" => "image/jpeg" })

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album.cover_image).to be_attached
    end
  end

  private

  def stub_playlist_api_calls
    stub_request(:get, "https://www.googleapis.com/youtube/v3/playlists")
      .with(query: hash_including(id: "PLtest123"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          items: [{
            snippet: {
              title: "Test Playlist",
              channelTitle: "Test Channel",
              thumbnails: { high: { url: "https://i.ytimg.com/vi/abc/hqdefault.jpg" } }
            },
            contentDetails: { itemCount: 2 }
          }]
        }.to_json
      )

    stub_request(:get, "https://www.googleapis.com/youtube/v3/playlistItems")
      .with(query: hash_including(playlistId: "PLtest123"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          items: [
            { snippet: { resourceId: { videoId: "vid1" }, title: "Song 1", position: 0, thumbnails: {} } },
            { snippet: { resourceId: { videoId: "vid2" }, title: "Song 2", position: 1, thumbnails: {} } }
          ]
        }.to_json
      )

    stub_request(:get, "https://www.googleapis.com/youtube/v3/videos")
      .with(query: hash_including(id: "vid1,vid2"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          items: [
            { id: "vid1", snippet: { title: "Song 1", channelTitle: "Test Channel" }, contentDetails: { duration: "PT3M45S" } },
            { id: "vid2", snippet: { title: "Song 2", channelTitle: "Test Channel" }, contentDetails: { duration: "PT4M10S" } }
          ]
        }.to_json
      )

    # Stub thumbnail download (may or may not be called)
    stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: { "Content-Type" => "image/jpeg" })
  end
end
