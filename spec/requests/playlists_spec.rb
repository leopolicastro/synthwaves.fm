require "rails_helper"

RSpec.describe "Playlists", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /playlists" do
    it "returns success" do
      get playlists_path
      expect(response).to have_http_status(:ok)
    end

    it "filters playlists by search query" do
      create(:playlist, user: user, name: "Chill Vibes")
      create(:playlist, user: user, name: "Rock Anthems")

      get playlists_path, params: {q: "Chill"}

      expect(response.body).to include("Chill Vibes")
      expect(response.body).not_to include("Rock Anthems")
    end

    it "sorts playlists by recently added (newest first) by default" do
      create(:playlist, user: user, name: "Older Playlist", created_at: 2.days.ago)
      create(:playlist, user: user, name: "Newer Playlist", created_at: 1.hour.ago)

      get playlists_path

      expect(response.body.index("Newer Playlist")).to be < response.body.index("Older Playlist")
    end

    it "sorts playlists by specified column and direction" do
      create(:playlist, user: user, name: "Old", created_at: 1.week.ago)
      create(:playlist, user: user, name: "New", created_at: 1.hour.ago)

      get playlists_path, params: {sort: "created_at", direction: "desc"}

      expect(response.body.index("New")).to be < response.body.index("Old")
    end

    it "paginates results" do
      get playlists_path
      expect(response).to have_http_status(:ok)
    end

    it "renders playlists in a grid layout" do
      create(:playlist, user: user, name: "My Playlist")
      get playlists_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".collection-grid")).to be_present
    end

    it "does not show edit or delete buttons" do
      playlist = create(:playlist, user: user, name: "My Playlist")
      get playlists_path

      doc = Nokogiri::HTML(response.body)
      delete_form = doc.at_css("form[action='#{playlist_path(playlist)}'] input[name='_method'][value='delete']")
      expect(delete_form).not_to be_present
      expect(response.body).not_to include(edit_playlist_path(playlist))
    end

    it "renders album cover images for playlists with covers" do
      playlist = create(:playlist, user: user, name: "With Covers")
      album = create(:album)
      album.cover_image.attach(io: StringIO.new("fake"), filename: "cover.jpg", content_type: "image/jpeg")
      track = create(:track, album: album, artist: album.artist)
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      get playlists_path

      doc = Nokogiri::HTML(response.body)
      card = doc.at_css(".collection-card")
      expect(card.at_css("img")).to be_present
    end

    it "renders placeholder for playlists without covers" do
      create(:playlist, user: user, name: "Empty")
      get playlists_path

      doc = Nokogiri::HTML(response.body)
      card = doc.at_css(".collection-card")
      expect(card.at_css("svg")).to be_present
      expect(card.at_css("img")).not_to be_present
    end

    it "displays track count from counter cache" do
      playlist = create(:playlist, user: user, name: "My Playlist")
      create(:playlist_track, playlist: playlist, track: create(:track), position: 1)
      playlist.reload

      get playlists_path

      expect(response.body).to include("1 track")
    end
  end

  describe "POST /playlists" do
    it "creates a playlist" do
      expect {
        post playlists_path, params: {playlist: {name: "My Playlist"}}
      }.to change(Playlist, :count).by(1)
      expect(response).to redirect_to(playlist_path(Playlist.last))
    end

    it "rejects blank name" do
      post playlists_path, params: {playlist: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates a playlist and populates with tracks when track_ids present" do
      track1 = create(:track)
      track2 = create(:track)

      expect {
        post playlists_path, params: {playlist: {name: "Bulk Playlist"}, track_ids: [track1.id, track2.id]}
      }.to change(Playlist, :count).by(1)

      playlist = Playlist.last
      expect(playlist.name).to eq("Bulk Playlist")
      expect(playlist.tracks).to eq([track1, track2])
      expect(playlist.playlist_tracks.order(:position).pluck(:position)).to eq([1, 2])
    end

    it "creates a playlist without tracks when track_ids absent" do
      expect {
        post playlists_path, params: {playlist: {name: "Empty Playlist"}}
      }.to change(Playlist, :count).by(1)

      expect(Playlist.last.tracks).to be_empty
    end
  end

  describe "PATCH /playlists/:id" do
    let(:playlist) { create(:playlist, user: user) }

    it "updates the playlist" do
      patch playlist_path(playlist), params: {playlist: {name: "Updated"}}
      expect(playlist.reload.name).to eq("Updated")
    end
  end

  describe "GET /playlists/:id" do
    let(:playlist) { create(:playlist, user: user) }
    let(:track) { create(:track) }

    before do
      create(:playlist_track, playlist: playlist, track: track, position: 1)
      get playlist_path(playlist)
    end

    it "renders song-row controller on each track" do
      expect(response.body).to include('data-controller="song-row now-playing"')
    end

    it "renders play button with correct data-action" do
      expect(response.body).to include('data-action="song-row#play"')
    end

    it "renders stream URL value" do
      expect(response.body).to include("data-song-row-stream-url-value")
    end

    it "renders track id value" do
      expect(response.body).to include("data-song-row-track-id-value=\"#{track.id}\"")
    end

    it "does not nest the play button inside a form" do
      doc = Nokogiri::HTML(response.body)
      play_button = doc.at_css('button[data-action="song-row#play"]')
      expect(play_button).to be_present
      expect(play_button.ancestors("form")).to be_empty
    end

    it "renders a copy track list button" do
      expect(response.body).to include("Copy track list")
    end

    it "includes track info in clipboard data attribute" do
      doc = Nokogiri::HTML(response.body)
      clipboard_div = doc.at_css('[data-controller="clipboard"]')
      content = clipboard_div["data-clipboard-content-value"]

      expect(content).to include("#{track.artist.name} - #{track.title}")
    end

    it "displays track count and total duration" do
      track_with_duration = create(:track, duration: 245)
      create(:playlist_track, playlist: playlist, track: track_with_duration, position: 2)
      get playlist_path(playlist)

      expect(response.body).to include("2 tracks")
      expect(response.body).to include("7:05")
    end

    it "includes YouTube URL for YouTube tracks" do
      youtube_track = create(:track, youtube_video_id: "abc123")
      create(:playlist_track, playlist: playlist, track: youtube_track, position: 2)
      get playlist_path(playlist)

      doc = Nokogiri::HTML(response.body)
      clipboard_div = doc.at_css('[data-controller="clipboard"]')
      content = clipboard_div["data-clipboard-content-value"]

      expect(content).to include("https://youtube.com/watch?v=abc123")
    end
  end

  describe "DELETE /playlists/:id" do
    let!(:playlist) { create(:playlist, user: user) }

    it "deletes the playlist" do
      expect {
        delete playlist_path(playlist)
      }.to change(Playlist, :count).by(-1)
    end
  end
end
