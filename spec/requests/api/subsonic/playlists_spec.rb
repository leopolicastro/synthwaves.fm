require "rails_helper"

RSpec.describe "Subsonic Playlists API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getPlaylists.view" do
    it "returns user playlists" do
      create(:playlist, user: user, name: "My Playlist")
      get "/api/rest/getPlaylists.view", params: auth_params
      json = JSON.parse(response.body)
      playlists = json["subsonic-response"]["playlists"]["playlist"]
      expect(playlists.last["name"]).to eq("My Playlist")
    end

    it "includes All Tracks virtual playlist first" do
      create_list(:track, 3, user: user)
      get "/api/rest/getPlaylists.view", params: auth_params
      json = JSON.parse(response.body)
      playlists = json["subsonic-response"]["playlists"]["playlist"]
      all_tracks = playlists.first
      expect(all_tracks["id"]).to eq("all")
      expect(all_tracks["name"]).to eq("All Tracks")
      expect(all_tracks["songCount"]).to eq(3)
    end

    it "includes Podcasts virtual playlist second" do
      podcast_artist = create(:artist, :podcast, user: user)
      podcast_album = create(:album, artist: podcast_artist, user: user)
      create_list(:track, 2, album: podcast_album, artist: podcast_artist, user: user)
      create_list(:track, 3, user: user)

      get "/api/rest/getPlaylists.view", params: auth_params
      json = JSON.parse(response.body)
      playlists = json["subsonic-response"]["playlists"]["playlist"]
      expect(playlists[0]["id"]).to eq("all")
      expect(playlists[0]["songCount"]).to eq(3)
      expect(playlists[1]["id"]).to eq("podcasts")
      expect(playlists[1]["name"]).to eq("Podcasts")
      expect(playlists[1]["songCount"]).to eq(2)
    end

    it "does not return other users playlists" do
      other = create(:user)
      create(:playlist, user: other)
      get "/api/rest/getPlaylists.view", params: auth_params
      json = JSON.parse(response.body)
      playlists = json["subsonic-response"]["playlists"]["playlist"]
      # Only the virtual playlists should be present
      expect(playlists.size).to eq(2)
      expect(playlists.map { |p| p["id"] }).to eq(%w[all podcasts])
    end
  end

  describe "GET /api/rest/getPlaylist.view" do
    it "returns playlist with entries" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)
      create(:playlist_track, playlist: playlist, track: track, position: 1)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: playlist.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["playlist"]["entry"]).to be_present
    end

    it "returns all tracks when id is 'all' excluding podcasts" do
      podcast_artist = create(:artist, :podcast, user: user)
      podcast_album = create(:album, artist: podcast_artist, user: user)
      create_list(:track, 2, album: podcast_album, artist: podcast_artist, user: user)
      create_list(:track, 3, user: user)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: "all")
      json = JSON.parse(response.body)
      playlist = json["subsonic-response"]["playlist"]
      expect(playlist["id"]).to eq("all")
      expect(playlist["name"]).to eq("All Tracks")
      expect(playlist["entry"].size).to eq(3)
    end

    it "returns only podcast tracks when id is 'podcasts'" do
      podcast_artist = create(:artist, :podcast, user: user)
      podcast_album = create(:album, artist: podcast_artist, user: user)
      create_list(:track, 2, album: podcast_album, artist: podcast_artist, user: user)
      create_list(:track, 3, user: user)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: "podcasts")
      json = JSON.parse(response.body)
      playlist = json["subsonic-response"]["playlist"]
      expect(playlist["id"]).to eq("podcasts")
      expect(playlist["name"]).to eq("Podcasts")
      expect(playlist["entry"].size).to eq(2)
    end

    it "returns at most 5 recent episodes per podcast" do
      podcast_artist = create(:artist, :podcast, user: user)
      podcast_album = create(:album, artist: podcast_artist, user: user)
      (1..7).map do |i|
        create(:track, title: "Episode #{i}", album: podcast_album, artist: podcast_artist, user: user,
          created_at: i.days.ago)
      end

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: "podcasts")
      json = JSON.parse(response.body)
      entries = json["subsonic-response"]["playlist"]["entry"]
      expect(entries.size).to eq(5)
      expect(entries.map { |e| e["title"] }).to eq(["Episode 1", "Episode 2", "Episode 3", "Episode 4", "Episode 5"])
    end

    it "returns 5 recent episodes per podcast across multiple podcasts" do
      podcast1 = create(:artist, :podcast, name: "Podcast One", user: user)
      album1 = create(:album, artist: podcast1, user: user)
      6.times { |i| create(:track, title: "P1 Ep #{i + 1}", album: album1, artist: podcast1, user: user, created_at: i.days.ago) }

      podcast2 = create(:artist, :podcast, name: "Podcast Two", user: user)
      album2 = create(:album, artist: podcast2, user: user)
      3.times { |i| create(:track, title: "P2 Ep #{i + 1}", album: album2, artist: podcast2, user: user, created_at: i.days.ago) }

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: "podcasts")
      json = JSON.parse(response.body)
      entries = json["subsonic-response"]["playlist"]["entry"]
      # 5 from podcast1 + 3 from podcast2
      expect(entries.size).to eq(8)
      p1_entries = entries.select { |e| e["title"].start_with?("P1") }
      p2_entries = entries.select { |e| e["title"].start_with?("P2") }
      expect(p1_entries.size).to eq(5)
      expect(p2_entries.size).to eq(3)
    end

    it "excludes YouTube tracks from virtual 'all' playlist" do
      create_list(:track, 3, user: user)
      create(:track, :youtube, user: user)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: "all")
      json = JSON.parse(response.body)
      playlist = json["subsonic-response"]["playlist"]
      expect(playlist["entry"].size).to eq(3)
      expect(playlist["songCount"]).to eq(3)
    end

    it "excludes tracks without audio files from user playlists" do
      playlist = create(:playlist, user: user)
      streamable = create(:track, title: "Streamable", user: user)
      youtube = create(:track, :youtube, title: "No Audio", user: user)
      create(:playlist_track, playlist: playlist, track: streamable, position: 1)
      create(:playlist_track, playlist: playlist, track: youtube, position: 2)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: playlist.id)
      json = JSON.parse(response.body)
      entries = json["subsonic-response"]["playlist"]["entry"]
      expect(entries.size).to eq(1)
      expect(entries.first["title"]).to eq("Streamable")
      expect(json["subsonic-response"]["playlist"]["songCount"]).to eq(1)
    end

    it "includes downloaded YouTube tracks in user playlists" do
      playlist = create(:playlist, user: user)
      downloaded_youtube = create(:track, :youtube, title: "Downloaded YouTube", user: user)
      downloaded_youtube.audio_file.attach(
        io: StringIO.new("fake audio data"),
        filename: "track.mp3",
        content_type: "audio/mpeg"
      )
      create(:playlist_track, playlist: playlist, track: downloaded_youtube, position: 1)

      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: playlist.id)
      json = JSON.parse(response.body)
      entries = json["subsonic-response"]["playlist"]["entry"]
      expect(entries.size).to eq(1)
      expect(entries.first["title"]).to eq("Downloaded YouTube")
    end

    it "returns error for nonexistent playlist" do
      get "/api/rest/getPlaylist.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/createPlaylist.view" do
    it "creates a new playlist" do
      expect {
        get "/api/rest/createPlaylist.view", params: auth_params.merge(name: "New One")
      }.to change(Playlist, :count).by(1)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["playlist"]["name"]).to eq("New One")
    end

    it "updates an existing playlist name" do
      playlist = create(:playlist, user: user, name: "Old Name")
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: playlist.id, name: "New Name")
      expect(playlist.reload.name).to eq("New Name")
    end

    it "sets songs on playlist" do
      playlist = create(:playlist, user: user)
      track = create(:track, user: user)
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: playlist.id, songId: [track.id])
      expect(playlist.reload.tracks).to include(track)
    end

    it "returns error for another user's playlist" do
      other = create(:user)
      playlist = create(:playlist, user: other)
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: playlist.id, name: "Hijack")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/createPlaylist.view" do
    # ... existing tests above ...

    it "returns error when trying to modify the All Tracks playlist" do
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: "all", name: "Renamed")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error when trying to modify the Podcasts playlist" do
      get "/api/rest/createPlaylist.view", params: auth_params.merge(playlistId: "podcasts", name: "Renamed")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "GET /api/rest/deletePlaylist.view" do
    it "deletes user's playlist" do
      playlist = create(:playlist, user: user)
      expect {
        get "/api/rest/deletePlaylist.view", params: auth_params.merge(id: playlist.id)
      }.to change(Playlist, :count).by(-1)
    end

    it "returns error when trying to delete the All Tracks playlist" do
      get "/api/rest/deletePlaylist.view", params: auth_params.merge(id: "all")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error when trying to delete the Podcasts playlist" do
      get "/api/rest/deletePlaylist.view", params: auth_params.merge(id: "podcasts")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error for nonexistent playlist" do
      get "/api/rest/deletePlaylist.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end
end
