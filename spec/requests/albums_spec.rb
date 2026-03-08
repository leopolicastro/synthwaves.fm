require "rails_helper"

RSpec.describe "Albums", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /albums" do
    it "returns success" do
      create(:album)
      get albums_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /albums/:id" do
    it "returns success" do
      album = create(:album)
      get album_path(album)
      expect(response).to have_http_status(:ok)
    end

    it "sorts by disc/track number by default" do
      album = create(:album)
      track_b = create(:track, album: album, disc_number: 1, track_number: 2, title: "Beta")
      track_a = create(:track, album: album, disc_number: 1, track_number: 1, title: "Alpha")
      track_c = create(:track, album: album, disc_number: 2, track_number: 1, title: "Charlie")

      get album_path(album)

      expect(response.body.index(track_a.title)).to be < response.body.index(track_b.title)
      expect(response.body.index(track_b.title)).to be < response.body.index(track_c.title)
    end

    it "sorts by created_at desc (newest first)" do
      album = create(:album)
      old_track = create(:track, album: album, title: "Old Track", created_at: 2.days.ago)
      new_track = create(:track, album: album, title: "New Track", created_at: 1.hour.ago)

      get album_path(album, sort: "created_at", direction: "desc")

      expect(response.body.index(new_track.title)).to be < response.body.index(old_track.title)
    end

    it "sorts by title asc (alphabetical)" do
      album = create(:album)
      track_z = create(:track, album: album, title: "Zebra")
      track_a = create(:track, album: album, title: "Apple")

      get album_path(album, sort: "title", direction: "asc")

      expect(response.body.index(track_a.title)).to be < response.body.index(track_z.title)
    end

    it "falls back to disc_number for invalid sort column" do
      album = create(:album)
      track_b = create(:track, album: album, disc_number: 1, track_number: 2, title: "Beta")
      track_a = create(:track, album: album, disc_number: 1, track_number: 1, title: "Alpha")

      get album_path(album, sort: "nonexistent_column")

      expect(response).to have_http_status(:ok)
      expect(response.body.index(track_a.title)).to be < response.body.index(track_b.title)
    end

    it "paginates when more than 20 tracks" do
      album = create(:album)
      21.times { |i| create(:track, album: album, track_number: i + 1, title: "Track #{(i + 1).to_s.rjust(3, '0')}") }

      get album_path(album)

      expect(response.body).to include("page=2")
    end

    it "does not show pagination nav with 20 or fewer tracks" do
      album = create(:album)
      5.times { |i| create(:track, album: album, track_number: i + 1) }

      get album_path(album)

      expect(response.body).not_to include("page=2")
    end
  end

  describe "POST /albums/:id/refresh" do
    let(:album) { create(:album, youtube_playlist_url: "https://www.youtube.com/playlist?list=PLtest123") }

    before do
      Flipper.enable(:youtube_import)
    end

    it "refreshes episodes and reports new count" do
      create(:track, album: album, youtube_video_id: "vid1")

      allow(YoutubePlaylistImportService).to receive(:call) do
        create(:track, album: album, youtube_video_id: "vid2")
        album
      end

      post refresh_album_path(album)

      expect(YoutubePlaylistImportService).to have_received(:call)
        .with(album.youtube_playlist_url, category: album.artist.category)
      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("1 new episode added")
    end

    it "reports when no new episodes found" do
      allow(YoutubePlaylistImportService).to receive(:call).and_return(album)

      post refresh_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("No new episodes found")
    end

    it "redirects with error when album has no youtube_playlist_url" do
      album_without_url = create(:album, youtube_playlist_url: nil)

      post refresh_album_path(album_without_url)

      expect(response).to redirect_to(album_path(album_without_url))
      follow_redirect!
      expect(response.body).to include("no YouTube playlist URL")
    end

    it "redirects with error when youtube import fails" do
      allow(YoutubePlaylistImportService).to receive(:call)
        .and_raise(YoutubePlaylistImportService::Error, "API quota exceeded")

      post refresh_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("Refresh failed: API quota exceeded")
    end

    it "redirects with error when feature flag is disabled" do
      Flipper.disable(:youtube_import)

      post refresh_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("This feature is not available")
    end
  end

  describe "POST /albums/:id/fetch_cover" do
    it "calls the service and redirects with success notice" do
      album = create(:album)
      allow(CoverArtSearchService).to receive(:call).with(album).and_return(:itunes)

      post fetch_cover_album_path(album)

      expect(CoverArtSearchService).to have_received(:call).with(album)
      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("Cover art updated from itunes source")
    end

    it "redirects with alert when no cover found" do
      album = create(:album)
      allow(CoverArtSearchService).to receive(:call).with(album).and_return(:not_found)

      post fetch_cover_album_path(album)

      expect(response).to redirect_to(album_path(album))
      follow_redirect!
      expect(response.body).to include("No cover art found")
    end

    it "requires authentication" do
      album = create(:album)
      reset!
      post fetch_cover_album_path(album)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PATCH /albums/:id" do
    it "saves the youtube_playlist_url" do
      album = create(:album, youtube_playlist_url: nil)

      patch album_path(album), params: {album: {youtube_playlist_url: "https://www.youtube.com/playlist?list=PLnew"}}

      expect(response).to redirect_to(album_path(album))
      expect(album.reload.youtube_playlist_url).to eq("https://www.youtube.com/playlist?list=PLnew")
    end

    it "clears the youtube_playlist_url" do
      album = create(:album, youtube_playlist_url: "https://www.youtube.com/playlist?list=PLold")

      patch album_path(album), params: {album: {youtube_playlist_url: ""}}

      expect(album.reload.youtube_playlist_url).to eq("")
    end

    it "requires authentication" do
      album = create(:album)
      reset!
      patch album_path(album), params: {album: {youtube_playlist_url: "https://example.com"}}
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "POST /albums/:id/create_playlist" do
    it "creates a playlist named after the album with all tracks in disc/track order" do
      album = create(:album, title: "Great Album")
      track3 = create(:track, album: album, disc_number: 2, track_number: 1, title: "Disc 2 Track 1")
      track1 = create(:track, album: album, disc_number: 1, track_number: 1, title: "Disc 1 Track 1")
      track2 = create(:track, album: album, disc_number: 1, track_number: 2, title: "Disc 1 Track 2")

      expect {
        post create_playlist_album_path(album)
      }.to change(Playlist, :count).by(1)

      playlist = user.playlists.last
      expect(playlist.name).to eq("Great Album")
      expect(playlist.playlist_tracks.order(:position).map(&:track)).to eq([track1, track2, track3])
      expect(response).to redirect_to(playlist_path(playlist))
    end

    it "requires authentication" do
      album = create(:album)
      reset!
      post create_playlist_album_path(album)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
