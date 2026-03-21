require "rails_helper"

RSpec.describe YoutubeVideoImportService do
  let(:api_key) { "test_api_key" }
  let(:user) { create(:user) }

  describe ".call" do
    it "raises error for invalid URL" do
      expect { described_class.call("https://example.com/not-a-video", api_key: api_key, user: user) }
        .to raise_error(YoutubeVideoImportService::Error, "Invalid YouTube video URL")
    end

    it "raises error when video is not found" do
      stub_request(:get, "https://www.googleapis.com/youtube/v3/videos")
        .with(query: hash_including(id: "R-FxmoVM7X4"))
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {items: []}.to_json
        )

      expect { described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user) }
        .to raise_error(YoutubeVideoImportService::Error, "Video not found")
    end

    it "imports a video as a track under a YouTube Singles album" do
      stub_video_api_call

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track).to be_persisted
      expect(track.title).to eq("Test Song")
      expect(track.youtube_video_id).to eq("R-FxmoVM7X4")
      expect(track.album.title).to eq("YouTube Singles")
    end

    it "uses channel name as artist when title has no dash" do
      stub_video_api_call

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.artist.name).to eq("Test Channel")
    end

    it "parses artist from 'Artist - Song' title format" do
      stub_video_api_call(title: "Daft Punk - Around The World (Official Video)")

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.artist.name).to eq("Daft Punk")
      expect(track.title).to eq("Around The World")
    end

    it "strips bracket noise from title" do
      stub_video_api_call(title: "Artist - Song [Official Audio] [HD]")

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.artist.name).to eq("Artist")
      expect(track.title).to eq("Song")
    end

    it "preserves feat. in parsed title" do
      stub_video_api_call(title: "Artist - Song (feat. Other)")

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.title).to eq("Song (feat. Other)")
    end

    it "sets youtube_video_id and duration" do
      stub_video_api_call

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.youtube_video_id).to eq("R-FxmoVM7X4")
      expect(track.duration).to eq(225.0)
    end

    it "auto-increments track numbers" do
      stub_video_api_call(video_id: "R-FxmoVM7X4")
      stub_video_api_call(video_id: "abc12345678", title: "Second Song")

      track1 = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)
      track2 = described_class.call("https://youtu.be/abc12345678", api_key: api_key, user: user)

      expect(track1.track_number).to eq(1)
      expect(track2.track_number).to eq(2)
    end

    it "returns existing track on duplicate import without creating a new record" do
      stub_video_api_call

      track1 = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)
      track2 = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track2.id).to eq(track1.id)
      expect(Track.where(youtube_video_id: "R-FxmoVM7X4").count).to eq(1)
    end

    it "creates a music artist by default" do
      stub_video_api_call

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.artist).to be_music
    end

    it "creates a podcast artist when category is podcast" do
      stub_video_api_call

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", category: "podcast", api_key: api_key, user: user)

      expect(track.artist).to be_podcast
    end

    it "attaches thumbnail as album cover" do
      stub_video_api_call
      stub_request(:get, "https://i.ytimg.com/vi/R-FxmoVM7X4/hqdefault.jpg")
        .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.album.cover_image).to be_attached
    end

    it "does not overwrite existing cover on subsequent imports" do
      stub_video_api_call(video_id: "R-FxmoVM7X4")
      stub_video_api_call(video_id: "abc12345678", title: "Second Song")
      stub_request(:get, "https://i.ytimg.com/vi/R-FxmoVM7X4/hqdefault.jpg")
        .to_return(status: 200, body: "first_image", headers: {"Content-Type" => "image/jpeg"})
      stub_request(:get, "https://i.ytimg.com/vi/abc12345678/hqdefault.jpg")
        .to_return(status: 200, body: "second_image", headers: {"Content-Type" => "image/jpeg"})

      track1 = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)
      described_class.call("https://youtu.be/abc12345678", api_key: api_key, user: user)

      # Cover should still be the first image
      expect(track1.album.cover_image.blob.download).to eq("first_image")
    end
  end

  context "without API key (yt-dlp fallback)" do
    let(:api_key) { nil }

    it "imports a video using yt-dlp metadata" do
      stub_ytdlp_metadata

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track).to be_persisted
      expect(track.title).to eq("Test Song")
      expect(track.youtube_video_id).to eq("R-FxmoVM7X4")
      expect(track.album.title).to eq("YouTube Singles")
    end

    it "uses channel name as artist when title has no dash" do
      stub_ytdlp_metadata

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.artist.name).to eq("Test Channel")
    end

    it "parses artist from 'Artist - Song' title format" do
      stub_ytdlp_metadata(title: "Daft Punk - Around The World (Official Video)")

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.artist.name).to eq("Daft Punk")
      expect(track.title).to eq("Around The World")
    end

    it "sets duration from yt-dlp metadata" do
      stub_ytdlp_metadata

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.duration).to eq(225.0)
    end

    it "returns existing track on duplicate import" do
      stub_ytdlp_metadata

      track1 = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)
      track2 = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track2.id).to eq(track1.id)
    end

    it "does not call YoutubeAPIService" do
      stub_ytdlp_metadata

      expect(YoutubeAPIService).not_to receive(:new)

      described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)
    end

    it "attaches thumbnail from yt-dlp metadata" do
      stub_ytdlp_metadata
      stub_request(:get, "https://i.ytimg.com/vi/R-FxmoVM7X4/maxresdefault.jpg")
        .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})

      track = described_class.call("https://youtu.be/R-FxmoVM7X4", api_key: api_key, user: user)

      expect(track.album.cover_image).to be_attached
    end
  end

  private

  def stub_ytdlp_metadata(video_id: "R-FxmoVM7X4", title: "Test Song", channel: "Test Channel")
    json = {
      id: video_id,
      title: title,
      channel: channel,
      uploader: channel,
      duration: 225.0,
      thumbnail: "https://i.ytimg.com/vi/#{video_id}/maxresdefault.jpg",
      is_live: false
    }.to_json

    allow(Open3).to receive(:capture3).with(
      "yt-dlp", "--dump-json", "--no-download", "--no-playlist",
      "https://www.youtube.com/watch?v=#{video_id}"
    ).and_return([json, "", instance_double(Process::Status, success?: true)])

    stub_request(:get, "https://i.ytimg.com/vi/#{video_id}/maxresdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})
  end

  def stub_video_api_call(video_id: "R-FxmoVM7X4", title: "Test Song", channel: "Test Channel")
    stub_request(:get, "https://www.googleapis.com/youtube/v3/videos")
      .with(query: hash_including(id: video_id))
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          items: [{
            id: video_id,
            snippet: {
              title: title,
              channelTitle: channel,
              thumbnails: {high: {url: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"}}
            },
            contentDetails: {duration: "PT3M45S"}
          }]
        }.to_json
      )

    # Stub thumbnail download (may or may not be called)
    stub_request(:get, "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg")
      .to_return(status: 200, body: "fake_image_data", headers: {"Content-Type" => "image/jpeg"})
  end
end
