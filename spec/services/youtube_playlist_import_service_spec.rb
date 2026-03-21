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

    it "parses artist from track titles in 'Artist - Song' format" do
      stub_playlist_api_calls(
        track_titles: ["Daft Punk - Around The World (Official Video)", "Kraftwerk - Trans-Europe Express"]
      )

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      track1 = album.tracks.find_by(youtube_video_id: "vid1")
      expect(track1.title).to eq("Around The World")
      expect(track1.artist.name).to eq("Daft Punk")

      track2 = album.tracks.find_by(youtube_video_id: "vid2")
      expect(track2.title).to eq("Trans-Europe Express")
      expect(track2.artist.name).to eq("Kraftwerk")
    end

    it "uses playlist artist when track title has no dash" do
      stub_playlist_api_calls(track_titles: ["Song Without Dash", "Another Song"])

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      track1 = album.tracks.find_by(youtube_video_id: "vid1")
      expect(track1.artist.name).to eq("Test Channel")
    end

    it "handles mixed parsed and unparsed track titles" do
      stub_playlist_api_calls(track_titles: ["Daft Punk - Da Funk", "Just A Song Title"])

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      track1 = album.tracks.find_by(youtube_video_id: "vid1")
      expect(track1.artist.name).to eq("Daft Punk")

      track2 = album.tracks.find_by(youtube_video_id: "vid2")
      expect(track2.artist.name).to eq("Test Channel")
    end

    it "downloads and attaches the thumbnail" do
      stub_playlist_api_calls
      stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
        .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album.cover_image).to be_attached
    end
  end

  context "without API key (yt-dlp fallback)" do
    let(:api_key) { nil }

    it "imports a playlist using yt-dlp metadata" do
      stub_ytdlp_playlist_metadata

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album).to be_persisted
      expect(album.title).to eq("Test Playlist")
      expect(album.artist.name).to eq("Test Channel")
      expect(album.tracks.count).to eq(2)

      track1 = album.tracks.find_by(youtube_video_id: "vid1")
      expect(track1.title).to eq("Song 1")
      expect(track1.track_number).to eq(1)
      expect(track1.duration).to eq(225.0)
    end

    it "does not call YoutubeAPIService" do
      stub_ytdlp_playlist_metadata

      expect(YoutubeAPIService).not_to receive(:new)

      described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)
    end

    it "parses artist from track titles" do
      stub_ytdlp_playlist_metadata(track_titles: ["Daft Punk - Around The World", "Kraftwerk - Trans-Europe Express"])

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      track1 = album.tracks.find_by(youtube_video_id: "vid1")
      expect(track1.artist.name).to eq("Daft Punk")
      expect(track1.title).to eq("Around The World")
    end

    it "saves youtube_playlist_url on the album" do
      stub_ytdlp_playlist_metadata

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album.youtube_playlist_url).to eq("https://www.youtube.com/playlist?list=PLtest123")
    end

    it "returns nil when playlist has no entries" do
      stub_ytdlp_playlist_metadata(track_titles: [])

      album = described_class.call("https://www.youtube.com/playlist?list=PLtest123", api_key: api_key, user: user)

      expect(album).to be_nil
    end
  end

  private

  def stub_ytdlp_playlist_metadata(track_titles: ["Song 1", "Song 2"])
    entries = track_titles.each_with_index.map do |title, index|
      {"id" => "vid#{index + 1}", "title" => title, "duration" => 225.0}
    end

    json = {
      id: "PLtest123",
      title: "Test Playlist",
      channel: "Test Channel",
      uploader: "Test Channel",
      thumbnails: [
        {"url" => "https://i.ytimg.com/vi/abc/hqdefault.jpg", "preference" => 5}
      ],
      entries: entries
    }.to_json

    allow(Open3).to receive(:capture3).with(
      "yt-dlp", "--flat-playlist", "--dump-single-json", "--no-download",
      "https://www.youtube.com/playlist?list=PLtest123"
    ).and_return([json, "", instance_double(Process::Status, success?: true)])

    stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})
  end

  def stub_playlist_api_calls(track_titles: ["Song 1", "Song 2"])
    title1, title2 = track_titles

    stub_request(:get, "https://www.googleapis.com/youtube/v3/playlists")
      .with(query: hash_including(id: "PLtest123"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [{
            snippet: {
              title: "Test Playlist",
              channelTitle: "Test Channel",
              thumbnails: {high: {url: "https://i.ytimg.com/vi/abc/hqdefault.jpg"}}
            },
            contentDetails: {itemCount: 2}
          }]
        }.to_json
      )

    stub_request(:get, "https://www.googleapis.com/youtube/v3/playlistItems")
      .with(query: hash_including(playlistId: "PLtest123"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [
            {snippet: {resourceId: {videoId: "vid1"}, title: title1, position: 0, thumbnails: {}}},
            {snippet: {resourceId: {videoId: "vid2"}, title: title2, position: 1, thumbnails: {}}}
          ]
        }.to_json
      )

    stub_request(:get, "https://www.googleapis.com/youtube/v3/videos")
      .with(query: hash_including(id: "vid1,vid2"))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [
            {id: "vid1", snippet: {title: title1, channelTitle: "Test Channel"}, contentDetails: {duration: "PT3M45S"}},
            {id: "vid2", snippet: {title: title2, channelTitle: "Test Channel"}, contentDetails: {duration: "PT4M10S"}}
          ]
        }.to_json
      )

    # Stub thumbnail download (may or may not be called)
    stub_request(:get, "https://i.ytimg.com/vi/abc/hqdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})
  end
end
