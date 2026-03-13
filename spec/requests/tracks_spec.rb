require "rails_helper"

RSpec.describe "Tracks", type: :request do
  let(:user) { create(:user, admin: true) }

  before { login_user(user) }

  describe "GET /tracks" do
    it "returns success" do
      get tracks_path
      expect(response).to have_http_status(:ok)
    end

    it "paginates results" do
      create_list(:track, 25, album: create(:album, artist: create(:artist, user: user)))
      get tracks_path
      expect(response.body).to include("series-nav")
    end

    it "respects page parameter" do
      tracks = create_list(:track, 25, album: create(:album, artist: create(:artist, user: user)))
      get tracks_path, params: {page: 2}
      expect(response).to have_http_status(:ok)
    end

    it "filters tracks by search query" do
      matching = create(:track, title: "Bohemian Rhapsody", album: create(:album, artist: create(:artist, user: user)))
      non_matching = create(:track, title: "Stairway to Heaven", album: create(:album, artist: create(:artist, user: user)))

      get tracks_path, params: {q: "Bohemian"}

      expect(response.body).to include("Bohemian Rhapsody")
      expect(response.body).not_to include("Stairway to Heaven")
    end

    it "returns all tracks when query is empty" do
      track1 = create(:track, title: "Track Alpha", album: create(:album, artist: create(:artist, user: user)))
      track2 = create(:track, title: "Track Beta", album: create(:album, artist: create(:artist, user: user)))

      get tracks_path, params: {q: ""}

      expect(response.body).to include("Track Alpha")
      expect(response.body).to include("Track Beta")
    end

    it "excludes podcast tracks from index" do
      music_track = create(:track, title: "Music Song", album: create(:album, artist: create(:artist, user: user)))
      podcast_artist = create(:artist, :podcast, user: user)
      podcast_track = create(:track, title: "Podcast Episode", artist: podcast_artist, album: create(:album, artist: podcast_artist))

      get tracks_path

      expect(response.body).to include("Music Song")
      expect(response.body).not_to include("Podcast Episode")
    end

    it "shows empty state when no tracks match" do
      create(:track, title: "Something Else", album: create(:album, artist: create(:artist, user: user)))

      get tracks_path, params: {q: "xyznonexistent"}

      expect(response.body).to include("No tracks found")
    end

    it "sorts tracks by recently added (newest first) by default" do
      older = create(:track, title: "Older Track", album: create(:album, artist: create(:artist, user: user)), created_at: 2.days.ago)
      newer = create(:track, title: "Newer Track", album: create(:album, artist: create(:artist, user: user)), created_at: 1.hour.ago)

      get tracks_path

      expect(response.body.index("Newer Track")).to be < response.body.index("Older Track")
    end

    it "sorts tracks by title ascending" do
      create(:track, title: "Zebra Song", album: create(:album, artist: create(:artist, user: user)))
      create(:track, title: "Alpha Song", album: create(:album, artist: create(:artist, user: user)))

      get tracks_path, params: { sort: "title", direction: "asc" }

      expect(response.body.index("Alpha Song")).to be < response.body.index("Zebra Song")
    end
  end

  describe "GET /tracks/:id" do
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }

    it "returns success" do
      get track_path(track)
      expect(response).to have_http_status(:ok)
    end

    it "renders the add to playlist menu with search input" do
      playlist = create(:playlist, user: user, name: "My Favorites")
      get track_path(track)
      expect(response.body).to include("Add to playlist")
      expect(response.body).to include("My Favorites")
      expect(response.body).to include('data-playlist-menu-target="input"')
      expect(response.body).to include("Search playlists")
    end

    it "renders icon buttons with title attributes" do
      get track_path(track)

      doc = Nokogiri::HTML(response.body)
      play_btn = doc.at_css('button[title="Play"]')
      expect(play_btn).to be_present
      expect(play_btn["data-action"]).to eq("song-row#play")

      expect(doc.at_css('a[title="Edit"]')).to be_present
      expect(doc.at_css('button[title="Delete"]')).to be_present
    end

    it "renders download icon button only when audio file is attached" do
      youtube_track = create(:track, :youtube, album: create(:album, artist: create(:artist, user: user)))
      get track_path(youtube_track)
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('a[title="Download"]')).to be_nil

      get track_path(track)
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('a[title="Download"]')).to be_present
    end
  end

  describe "GET /tracks/new" do
    it "returns success" do
      get new_track_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tracks" do
    it "creates a track from uploaded audio file" do
      file = fixture_file_upload("test.mp3", "audio/mpeg")

      expect {
        post tracks_path, params: {audio_file: file}
      }.to change(Track, :count).by(1)

      track = Track.last
      expect(track.title).to eq("Test Song")
      expect(track.artist.name).to eq("Test Artist")
      expect(track.album.title).to eq("Test Album")
      expect(response).to redirect_to(track_path(track))
    end

    it "returns unprocessable_content without a file" do
      post tracks_path
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "reuses existing artist and album" do
      artist = create(:artist, name: "Test Artist", user: user)
      album = create(:album, title: "Test Album", artist: artist)

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      track = Track.last
      expect(track.artist).to eq(artist)
      expect(track.album).to eq(album)
    end

    it "does not overwrite existing album cover art" do
      artist = create(:artist, name: "Cover Artist", user: user)
      album = create(:album, title: "Cover Album", artist: artist)
      album.cover_image.attach(
        io: StringIO.new("existing cover"),
        filename: "existing.jpg",
        content_type: "image/jpeg"
      )
      original_blob_id = album.cover_image.blob.id

      allow(MetadataExtractor).to receive(:call).and_return({
        title: "Cover Song", artist: "Cover Artist", album: "Cover Album",
        year: 2024, genre: "Pop", track_number: 1, disc_number: 1,
        duration: 200.0, bitrate: 320,
        cover_art: {data: "new image data", mime_type: "image/jpeg"}
      })

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      expect(album.reload.cover_image.blob.id).to eq(original_blob_id)
    end

    it "attaches cover art to album when metadata includes it" do
      allow(MetadataExtractor).to receive(:call).and_return({
        title: "Cover Song", artist: "Cover Artist", album: "Cover Album",
        year: 2024, genre: "Pop", track_number: 1, disc_number: 1,
        duration: 200.0, bitrate: 320,
        cover_art: {data: "fake image data", mime_type: "image/jpeg"}
      })

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      track = Track.last
      expect(track.album.cover_image.attached?).to be true
    end
  end

  describe "PATCH /tracks/:id" do
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }

    it "updates the track" do
      patch track_path(track), params: {track: {title: "New Title"}}
      expect(track.reload.title).to eq("New Title")
      expect(response).to redirect_to(track_path(track))
    end

    it "rejects blank title" do
      patch track_path(track), params: {track: {title: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "moves track to a different album" do
      new_album = create(:album, title: "New Album", artist: create(:artist, user: user))
      patch track_path(track), params: {track: {album_id: new_album.id}}

      expect(track.reload.album).to eq(new_album)
    end

    it "moves track to a different artist" do
      new_artist = create(:artist, name: "New Artist", user: user)
      patch track_path(track), params: {track: {artist_id: new_artist.id}}

      expect(track.reload.artist).to eq(new_artist)
    end
  end

  describe "DELETE /tracks/:id" do
    let!(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }

    it "deletes the track" do
      expect {
        delete track_path(track)
      }.to change(Track, :count).by(-1)
      expect(response).to redirect_to(tracks_path)
    end
  end

  describe "authorization" do
    let(:non_admin) { create(:user, admin: false) }
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: non_admin))) }

    before { login_user(non_admin) }

    it "redirects non-admin from edit" do
      get edit_track_path(track)
      expect(response).to redirect_to(root_path)
    end

    it "redirects non-admin from update" do
      patch track_path(track), params: {track: {title: "Hacked"}}
      expect(response).to redirect_to(root_path)
      expect(track.reload.title).not_to eq("Hacked")
    end

    it "redirects non-admin from destroy" do
      delete track_path(track)
      expect(response).to redirect_to(root_path)
      expect(Track.exists?(track.id)).to be true
    end
  end

  describe "player bar layout" do
    it "does not render an <audio> element inside the player bar" do
      get tracks_path

      doc = Nokogiri::HTML(response.body)
      audio_in_player = doc.at_css("#player-bar audio")
      expect(audio_in_player).to be_nil,
        "Expected no <audio> inside #player-bar — it must be created by JS on " \
        "<html> (outside <body>) so Turbo navigation never detaches it"
    end
  end

  describe "GET /tracks/:id/download" do
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }

    it "redirects to blob with attachment disposition when audio file is attached" do
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get download_track_path(track)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("disposition=attachment")
    end

    it "redirects with alert for YouTube tracks without audio" do
      youtube_track = create(:track, youtube_video_id: "abc123", album: create(:album, artist: create(:artist, user: user)))

      get download_track_path(youtube_track)

      expect(response).to redirect_to(track_path(youtube_track))
      expect(flash[:alert]).to eq("This track is not available for download.")
    end

    it "allows download for YouTube tracks with audio file attached" do
      youtube_track = create(:track, youtube_video_id: "abc123", album: create(:album, artist: create(:artist, user: user)))
      youtube_track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get download_track_path(youtube_track)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("disposition=attachment")
    end

    it "redirects with alert when no audio file is attached" do
      youtube_track = create(:track, :youtube, album: create(:album, artist: create(:artist, user: user)))

      get download_track_path(youtube_track)

      expect(response).to redirect_to(track_path(youtube_track))
      expect(flash[:alert]).to eq("This track is not available for download.")
    end
  end

  describe "GET /tracks/:id/stream" do
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }

    it "returns not_found when no audio file is attached" do
      youtube_track = create(:track, :youtube, album: create(:album, artist: create(:artist, user: user)))
      get stream_track_path(youtube_track)
      expect(response).to have_http_status(:not_found)
    end

    it "streams YouTube tracks that have downloaded audio files" do
      youtube_track = create(:track, youtube_video_id: "abc123", album: create(:album, artist: create(:artist, user: user)))
      youtube_track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get stream_track_path(youtube_track)
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("rails/active_storage")
    end

    context "when audio file is attached" do
      before do
        track.audio_file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )
      end

      it "redirects to proxy URL with disk storage" do
        get stream_track_path(track)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("rails/active_storage")
      end

      it "redirects to proxy URL when proxy param is present" do
        get stream_track_path(track, proxy: "1")
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("rails/active_storage")
      end

      it "redirects to direct URL with cloud storage" do
        s3_url = "https://bucket.s3.amazonaws.com/test.mp3?signed=1"
        allow(ActiveStorage::Blob.service.class).to receive(:name)
          .and_return("ActiveStorage::Service::S3Service")
        allow_any_instance_of(ActiveStorage::Blob).to receive(:url).and_return(s3_url)

        get stream_track_path(track)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq(s3_url)
      end

      it "returns direct URL as JSON with resolve param on cloud storage" do
        s3_url = "https://bucket.s3.amazonaws.com/test.mp3?signed=1"
        allow(ActiveStorage::Blob.service.class).to receive(:name)
          .and_return("ActiveStorage::Service::S3Service")
        allow_any_instance_of(ActiveStorage::Blob).to receive(:url).and_return(s3_url)

        get stream_track_path(track, resolve: "1")
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["url"]).to eq(s3_url)
      end

      it "ignores resolve param with disk storage and redirects to proxy" do
        get stream_track_path(track, resolve: "1")
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("rails/active_storage")
      end
    end
  end

  describe "GET /tracks/:id/lyrics" do
    it "returns lyrics as JSON when present" do
      track = create(:track, :with_lyrics, album: create(:album, artist: create(:artist, user: user)))
      get lyrics_track_path(track), as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["lyrics"]).to include("Verse 1")
    end

    it "returns null lyrics when track has no lyrics and LRCLIB has none" do
      stub_request(:get, /lrclib\.net\/api\/search/)
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      track = create(:track, album: create(:album, artist: create(:artist, user: user)))
      get lyrics_track_path(track), as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["lyrics"]).to be_nil
    end
  end

  describe "PATCH /tracks/:id with lyrics" do
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }

    it "updates lyrics" do
      patch track_path(track), params: { track: { lyrics: "New lyrics here" } }
      expect(track.reload.lyrics).to eq("New lyrics here")
    end
  end
end
