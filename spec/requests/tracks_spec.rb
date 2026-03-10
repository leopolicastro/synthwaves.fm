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
      create_list(:track, 25)
      get tracks_path
      expect(response.body).to include("series-nav")
    end

    it "respects page parameter" do
      tracks = create_list(:track, 25)
      get tracks_path, params: {page: 2}
      expect(response).to have_http_status(:ok)
    end

    it "filters tracks by search query" do
      matching = create(:track, title: "Bohemian Rhapsody")
      non_matching = create(:track, title: "Stairway to Heaven")

      get tracks_path, params: {q: "Bohemian"}

      expect(response.body).to include("Bohemian Rhapsody")
      expect(response.body).not_to include("Stairway to Heaven")
    end

    it "returns all tracks when query is empty" do
      track1 = create(:track, title: "Track Alpha")
      track2 = create(:track, title: "Track Beta")

      get tracks_path, params: {q: ""}

      expect(response.body).to include("Track Alpha")
      expect(response.body).to include("Track Beta")
    end

    it "excludes podcast tracks from index" do
      music_track = create(:track, title: "Music Song")
      podcast_artist = create(:artist, :podcast)
      podcast_track = create(:track, title: "Podcast Episode", artist: podcast_artist)

      get tracks_path

      expect(response.body).to include("Music Song")
      expect(response.body).not_to include("Podcast Episode")
    end

    it "shows empty state when no tracks match" do
      create(:track, title: "Something Else")

      get tracks_path, params: {q: "xyznonexistent"}

      expect(response.body).to include("No tracks found")
    end
  end

  describe "GET /tracks/:id" do
    let(:track) { create(:track) }

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
      artist = create(:artist, name: "Test Artist")
      album = create(:album, title: "Test Album", artist: artist)

      file = fixture_file_upload("test.mp3", "audio/mpeg")
      post tracks_path, params: {audio_file: file}

      track = Track.last
      expect(track.artist).to eq(artist)
      expect(track.album).to eq(album)
    end

    it "does not overwrite existing album cover art" do
      artist = create(:artist, name: "Cover Artist")
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
    let(:track) { create(:track) }

    it "updates the track" do
      patch track_path(track), params: {track: {title: "New Title"}}
      expect(track.reload.title).to eq("New Title")
      expect(response).to redirect_to(track_path(track))
    end

    it "rejects blank title" do
      patch track_path(track), params: {track: {title: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /tracks/:id" do
    let!(:track) { create(:track) }

    it "deletes the track" do
      expect {
        delete track_path(track)
      }.to change(Track, :count).by(-1)
      expect(response).to redirect_to(tracks_path)
    end
  end

  describe "authorization" do
    let(:non_admin) { create(:user, admin: false) }
    let(:track) { create(:track) }

    before { login_user(non_admin) }

    it "redirects non-admin from edit" do
      get edit_track_path(track)
      expect(response).to redirect_to(tracks_path)
    end

    it "redirects non-admin from update" do
      patch track_path(track), params: {track: {title: "Hacked"}}
      expect(response).to redirect_to(tracks_path)
      expect(track.reload.title).not_to eq("Hacked")
    end

    it "redirects non-admin from destroy" do
      delete track_path(track)
      expect(response).to redirect_to(tracks_path)
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
    let(:track) { create(:track) }

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

    it "redirects with alert for YouTube tracks" do
      youtube_track = create(:track, youtube_video_id: "abc123")

      get download_track_path(youtube_track)

      expect(response).to redirect_to(track_path(youtube_track))
      expect(flash[:alert]).to eq("This track is not available for download.")
    end

    it "redirects with alert when no audio file is attached" do
      get download_track_path(track)

      expect(response).to redirect_to(track_path(track))
      expect(flash[:alert]).to eq("This track is not available for download.")
    end
  end

  describe "GET /tracks/:id/stream" do
    let(:track) { create(:track) }

    it "returns not_found when no audio file is attached" do
      get stream_track_path(track)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects when audio file is attached" do
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )
      get stream_track_path(track)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /tracks/:id/lyrics" do
    it "returns lyrics as JSON when present" do
      track = create(:track, :with_lyrics)
      get lyrics_track_path(track), as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["lyrics"]).to include("Verse 1")
    end

    it "returns null lyrics when track has no lyrics and LRCLIB has none" do
      stub_request(:get, /lrclib\.net\/api\/search/)
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      track = create(:track)
      get lyrics_track_path(track), as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["lyrics"]).to be_nil
    end
  end

  describe "PATCH /tracks/:id with lyrics" do
    let(:track) { create(:track) }

    it "updates lyrics" do
      patch track_path(track), params: { track: { lyrics: "New lyrics here" } }
      expect(track.reload.lyrics).to eq("New lyrics here")
    end
  end
end
