require "rails_helper"

RSpec.describe "YoutubeImports", type: :request do
  let(:user) { create(:user) }

  before do
    login_user(user)
    user.update!(youtube_api_key: "test_key")
  end

  describe "GET /youtube_imports/new" do
    it "returns success" do
      get new_youtube_import_path
      expect(response).to have_http_status(:ok)
    end

    it "renders media type radio buttons" do
      get new_youtube_import_path
      expect(response.body).to include("Download As")
      expect(response.body).to include("Audio (Track)")
      expect(response.body).to include("Video")
    end

    it "renders the playlist selector with user's playlists" do
      create(:playlist, user: user, name: "Chill Vibes")
      create(:playlist, name: "Not Mine")

      get new_youtube_import_path

      expect(response.body).to include("Add to Playlist")
      expect(response.body).to include("Chill Vibes")
      expect(response.body).to include("Create new playlist")
      expect(response.body).not_to include("Not Mine")
    end
  end

  describe "GET /youtube_imports/search" do
    it "returns search results for a valid query" do
      results = [
        {video_id: "abc123", title: "Test Video", channel_name: "Test Channel", thumbnail_url: "https://i.ytimg.com/vi/abc123/hqdefault.jpg"}
      ]
      api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).and_return(api)
      allow(api).to receive(:search_videos).with("lofi beats").and_return(results)

      get search_youtube_imports_path, params: {q: "lofi beats"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Video")
      expect(response.body).to include("Test Channel")
      expect(response.body).to include("youtube.com/watch?v=abc123")
    end

    it "shows no results message for empty results" do
      api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).and_return(api)
      allow(api).to receive(:search_videos).with("xyznosuchvideo").and_return([])

      get search_youtube_imports_path, params: {q: "xyznosuchvideo"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No results found")
    end

    it "handles API errors gracefully" do
      api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).and_return(api)
      allow(api).to receive(:search_videos).and_raise(YoutubeAPIService::Error, "Daily Limit Exceeded")

      get search_youtube_imports_path, params: {q: "test"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Daily Limit Exceeded")
    end

    it "requires authentication" do
      delete session_path
      get search_youtube_imports_path, params: {q: "test"}

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "POST /youtube_imports" do
    context "with audio media type (default)" do
      it "enqueues import job with download flag for playlists" do
        post youtube_imports_path, params: {youtube_url: "https://www.youtube.com/playlist?list=PLtest123"}

        expect(YoutubeImportJob).to have_been_enqueued.with(
          "https://www.youtube.com/playlist?list=PLtest123",
          category: "music",
          download: true,
          user_id: user.id,
          playlist_id: nil,
          new_playlist_name: nil
        )
        expect(response).to redirect_to(library_path)
      end

      it "passes the category parameter to the job" do
        post youtube_imports_path, params: {
          youtube_url: "https://www.youtube.com/playlist?list=PLtest123",
          category: "podcast"
        }

        expect(YoutubeImportJob).to have_been_enqueued.with(
          "https://www.youtube.com/playlist?list=PLtest123",
          category: "podcast",
          download: true,
          user_id: user.id,
          playlist_id: nil,
          new_playlist_name: nil
        )
      end

      it "passes playlist_id to the job when an existing playlist is selected" do
        playlist = create(:playlist, user: user)

        post youtube_imports_path, params: {
          youtube_url: "https://www.youtube.com/playlist?list=PLtest123",
          playlist_id: playlist.id.to_s
        }

        expect(YoutubeImportJob).to have_been_enqueued.with(
          "https://www.youtube.com/playlist?list=PLtest123",
          category: "music",
          download: true,
          user_id: user.id,
          playlist_id: playlist.id,
          new_playlist_name: nil
        )
      end

      it "passes new_playlist_name to the job when creating a new playlist" do
        post youtube_imports_path, params: {
          youtube_url: "https://www.youtube.com/playlist?list=PLtest123",
          playlist_id: "new",
          new_playlist_name: "My Import"
        }

        expect(YoutubeImportJob).to have_been_enqueued.with(
          "https://www.youtube.com/playlist?list=PLtest123",
          category: "music",
          download: true,
          user_id: user.id,
          playlist_id: nil,
          new_playlist_name: "My Import"
        )
      end

      context "with a single video URL" do
        let(:video_url) { "https://youtu.be/R-FxmoVM7X4" }

        it "imports metadata and enqueues MediaDownloadJob" do
          album = create(:album)
          track = create(:track, album: album, youtube_video_id: "R-FxmoVM7X4")
          allow(YoutubeVideoImportService).to receive(:call).and_return(track)

          post youtube_imports_path, params: {youtube_url: video_url}

          expect(YoutubeVideoImportService).to have_received(:call).with(video_url, category: "music", api_key: "test_key", user: user)
          expect(MediaDownloadJob).to have_been_enqueued.with(track.id, video_url, user_id: user.id)
          expect(response).to redirect_to(album_path(album))
        end

        it "passes the category parameter to the service" do
          album = create(:album)
          track = create(:track, album: album, youtube_video_id: "R-FxmoVM7X4")
          allow(YoutubeVideoImportService).to receive(:call).and_return(track)

          post youtube_imports_path, params: {youtube_url: video_url, category: "podcast"}

          expect(YoutubeVideoImportService).to have_received(:call).with(video_url, category: "podcast", api_key: "test_key", user: user)
        end

        it "adds the track to an existing playlist when playlist_id is given" do
          album = create(:album)
          track = create(:track, album: album, youtube_video_id: "R-FxmoVM7X4", user: user)
          playlist = create(:playlist, user: user)
          allow(YoutubeVideoImportService).to receive(:call).and_return(track)

          post youtube_imports_path, params: {youtube_url: video_url, playlist_id: playlist.id.to_s}

          expect(playlist.tracks).to include(track)
        end

        it "creates a new playlist and adds the track when playlist_id is 'new'" do
          album = create(:album)
          track = create(:track, album: album, youtube_video_id: "R-FxmoVM7X4", user: user)
          allow(YoutubeVideoImportService).to receive(:call).and_return(track)

          expect {
            post youtube_imports_path, params: {youtube_url: video_url, playlist_id: "new", new_playlist_name: "Fresh Imports"}
          }.to change(Playlist, :count).by(1)

          playlist = Playlist.last
          expect(playlist.name).to eq("Fresh Imports")
          expect(playlist.tracks).to include(track)
        end

        it "renders the form with an error when the service fails" do
          allow(YoutubeVideoImportService).to receive(:call)
            .and_raise(YoutubeVideoImportService::Error, "Video not found")

          post youtube_imports_path, params: {youtube_url: video_url}

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      it "rejects invalid URLs without enqueuing a job" do
        post youtube_imports_path, params: {youtube_url: "https://example.com"}

        expect(YoutubeImportJob).not_to have_been_enqueued
        expect(response).to have_http_status(:unprocessable_content)
      end

      context "with a URL containing both video and playlist params" do
        it "treats it as a playlist import" do
          url = "https://www.youtube.com/watch?v=R-FxmoVM7X4&list=PLtest123"

          post youtube_imports_path, params: {youtube_url: url}

          expect(YoutubeImportJob).to have_been_enqueued.with(
            url, category: "music", download: true, user_id: user.id,
            playlist_id: nil, new_playlist_name: nil
          )
        end
      end
    end

    context "without API key (yt-dlp fallback)" do
      before { user.update!(youtube_api_key: nil) }

      it "imports a single video using yt-dlp metadata" do
        album = create(:album)
        track = create(:track, album: album, youtube_video_id: "R-FxmoVM7X4")
        allow(YoutubeVideoImportService).to receive(:call).and_return(track)

        post youtube_imports_path, params: {youtube_url: "https://youtu.be/R-FxmoVM7X4"}

        expect(YoutubeVideoImportService).to have_received(:call).with(
          "https://youtu.be/R-FxmoVM7X4", category: "music", api_key: nil, user: user
        )
        expect(MediaDownloadJob).to have_been_enqueued.with(track.id, "https://youtu.be/R-FxmoVM7X4", user_id: user.id)
        expect(response).to redirect_to(album_path(album))
      end

      it "imports a playlist using yt-dlp metadata" do
        post youtube_imports_path, params: {youtube_url: "https://www.youtube.com/playlist?list=PLtest123"}

        expect(YoutubeImportJob).to have_been_enqueued.with(
          "https://www.youtube.com/playlist?list=PLtest123",
          category: "music",
          download: true,
          user_id: user.id,
          playlist_id: nil,
          new_playlist_name: nil
        )
      end

      it "handles MediaDownloadService errors gracefully" do
        allow(YoutubeVideoImportService).to receive(:call)
          .and_raise(MediaDownloadService::Error, "Failed to fetch video metadata")

        post youtube_imports_path, params: {youtube_url: "https://youtu.be/R-FxmoVM7X4"}

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with video media type" do
      it "creates a Video record and enqueues VideoDownloadJob for a single video" do
        details = {video_id: "dQw4w9WgXcQ", title: "Test Video", channel_name: "Test Channel", duration: 120.0}
        api = instance_double(YoutubeAPIService)
        allow(YoutubeAPIService).to receive(:new).and_return(api)
        allow(api).to receive(:fetch_video_details).with(["dQw4w9WgXcQ"]).and_return([details])

        expect {
          post youtube_imports_path, params: {
            youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            media_type: "video"
          }
        }.to change(Video, :count).by(1)

        video = Video.last
        expect(video.title).to eq("Test Video")
        expect(video.youtube_video_id).to eq("dQw4w9WgXcQ")
        expect(VideoDownloadJob).to have_been_enqueued.with(video.id, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", user_id: user.id)
        expect(response).to redirect_to(video_path(video))
      end

      context "without API key (yt-dlp fallback)" do
        before { user.update!(youtube_api_key: nil) }

        it "creates a Video using yt-dlp metadata and enqueues download" do
          metadata = {video_id: "dQw4w9WgXcQ", title: "Test Video", channel_name: "Test Channel", duration: 120.0, thumbnail_url: nil}
          allow(MediaDownloadService).to receive(:fetch_metadata).and_return(metadata)

          expect {
            post youtube_imports_path, params: {
              youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
              media_type: "video"
            }
          }.to change(Video, :count).by(1)

          video = Video.last
          expect(video.title).to eq("Test Video")
          expect(video.youtube_video_id).to eq("dQw4w9WgXcQ")
          expect(VideoDownloadJob).to have_been_enqueued.with(video.id, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", user_id: user.id)
        end

        it "does not call YoutubeAPIService" do
          metadata = {video_id: "dQw4w9WgXcQ", title: "Test Video", channel_name: "Test Channel", duration: 120.0, thumbnail_url: nil}
          allow(MediaDownloadService).to receive(:fetch_metadata).and_return(metadata)

          expect(YoutubeAPIService).not_to receive(:new)

          post youtube_imports_path, params: {
            youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            media_type: "video"
          }
        end
      end

      it "rejects playlist URLs for video import" do
        post youtube_imports_path, params: {
          youtube_url: "https://www.youtube.com/playlist?list=PLtest123",
          media_type: "video"
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("not supported for playlists")
      end

      it "rejects invalid URLs for video import" do
        post youtube_imports_path, params: {
          youtube_url: "https://example.com",
          media_type: "video"
        }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "redirects to existing video if already imported" do
        existing = create(:video, user: user, youtube_video_id: "dQw4w9WgXcQ")

        post youtube_imports_path, params: {
          youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
          media_type: "video"
        }

        expect(response).to redirect_to(video_path(existing))
      end
    end
  end
end
