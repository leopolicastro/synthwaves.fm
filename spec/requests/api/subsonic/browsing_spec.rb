require "rails_helper"

RSpec.describe "Subsonic Browsing API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getMusicFolders.view" do
    it "returns a single music folder" do
      get "/api/rest/getMusicFolders.view", params: auth_params
      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["musicFolders"]["musicFolder"]
      expect(folders).to eq([{"id" => 1, "name" => "Music"}])
    end
  end

  describe "GET /api/rest/getIndexes.view" do
    it "groups artists by first letter" do
      create(:artist, name: "Beatles", user: user)
      create(:artist, name: "ABBA", user: user)
      create(:artist, name: "123 Band", user: user)

      get "/api/rest/getIndexes.view", params: auth_params
      json = JSON.parse(response.body)
      indexes = json["subsonic-response"]["indexes"]["index"]
      letters = indexes.map { |i| i["name"] }
      expect(letters).to include("A", "B", "1")
    end
  end

  describe "GET /api/rest/getArtists.view" do
    it "returns artists grouped by letter" do
      create(:artist, name: "Beatles", user: user)
      create(:artist, name: "ABBA", user: user)

      get "/api/rest/getArtists.view", params: auth_params
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
      expect(json["subsonic-response"]["artists"]).to be_present
    end
  end

  describe "GET /api/rest/getArtist.view" do
    it "returns artist with albums" do
      artist = create(:artist, user: user)
      create(:album, artist: artist, user: user)

      get "/api/rest/getArtist.view", params: auth_params.merge(id: artist.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["artist"]["name"]).to eq(artist.name)
    end

    it "returns error for nonexistent artist" do
      get "/api/rest/getArtist.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/getAlbum.view" do
    it "returns album with tracks" do
      album = create(:album, user: user)
      create(:track, album: album, artist: album.artist, user: user)

      get "/api/rest/getAlbum.view", params: auth_params.merge(id: album.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["album"]["name"]).to eq(album.title)
      expect(json["subsonic-response"]["album"]["song"]).to be_present
    end

    it "excludes YouTube tracks from song list" do
      album = create(:album, user: user)
      create(:track, album: album, artist: album.artist, title: "Streamable", user: user)
      create(:track, :youtube, album: album, artist: album.artist, title: "YouTube Only", user: user)

      get "/api/rest/getAlbum.view", params: auth_params.merge(id: album.id)
      json = JSON.parse(response.body)
      songs = json["subsonic-response"]["album"]["song"]
      titles = songs.map { |s| s["title"] }
      expect(titles).to include("Streamable")
      expect(titles).not_to include("YouTube Only")
      expect(json["subsonic-response"]["album"]["songCount"]).to eq(1)
    end

    it "returns error for nonexistent album" do
      get "/api/rest/getAlbum.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["message"]).to eq("Album not found")
    end
  end

  describe "GET /api/rest/getSong.view" do
    it "returns song details" do
      track = create(:track, user: user)

      get "/api/rest/getSong.view", params: auth_params.merge(id: track.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["song"]["title"]).to eq(track.title)
    end

    it "returns error for YouTube track" do
      youtube_track = create(:track, :youtube, user: user)

      get "/api/rest/getSong.view", params: auth_params.merge(id: youtube_track.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error for nonexistent song" do
      get "/api/rest/getSong.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["message"]).to eq("Song not found")
    end
  end
end
