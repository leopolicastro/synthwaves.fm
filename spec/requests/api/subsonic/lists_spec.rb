require "rails_helper"

RSpec.describe "Subsonic Lists API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getAlbumList2.view" do
    let!(:album_a) { create(:album, title: "Alpha", year: 2020, genre: "Rock").tap { |a| create(:track, album: a, artist: a.artist) } }
    let!(:album_b) { create(:album, title: "Beta", year: 2022, genre: "Jazz").tap { |a| create(:track, album: a, artist: a.artist) } }

    it "returns albums alphabetically by name by default" do
      get "/api/rest/getAlbumList2.view", params: auth_params
      json = JSON.parse(response.body)
      albums = json["subsonic-response"]["albumList2"]["album"]
      expect(albums.first["name"]).to eq("Alpha")
    end

    it "returns newest albums first" do
      get "/api/rest/getAlbumList2.view", params: auth_params.merge(type: "newest")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["albumList2"]["album"]).to be_present
    end

    it "returns random albums" do
      get "/api/rest/getAlbumList2.view", params: auth_params.merge(type: "random")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["albumList2"]["album"]).to be_present
    end

    it "filters by year range" do
      get "/api/rest/getAlbumList2.view", params: auth_params.merge(type: "byYear", fromYear: 2021, toYear: 2023)
      json = JSON.parse(response.body)
      albums = json["subsonic-response"]["albumList2"]["album"]
      expect(albums.size).to eq(1)
      expect(albums.first["name"]).to eq("Beta")
    end

    it "filters by genre" do
      get "/api/rest/getAlbumList2.view", params: auth_params.merge(type: "byGenre", genre: "Rock")
      json = JSON.parse(response.body)
      albums = json["subsonic-response"]["albumList2"]["album"]
      expect(albums.size).to eq(1)
      expect(albums.first["name"]).to eq("Alpha")
    end

    it "respects size and offset" do
      get "/api/rest/getAlbumList2.view", params: auth_params.merge(size: 1, offset: 1)
      json = JSON.parse(response.body)
      albums = json["subsonic-response"]["albumList2"]["album"]
      expect(albums.size).to eq(1)
      expect(albums.first["name"]).to eq("Beta")
    end

    it "sorts alphabetically by artist" do
      get "/api/rest/getAlbumList2.view", params: auth_params.merge(type: "alphabeticalByArtist")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["albumList2"]["album"]).to be_present
    end
  end

  describe "GET /api/rest/getRandomSongs.view" do
    it "returns random songs" do
      create(:track)
      get "/api/rest/getRandomSongs.view", params: auth_params.merge(size: 5)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["randomSongs"]["song"]).to be_present
    end

    it "excludes YouTube tracks" do
      create_list(:track, 3)
      create(:track, :youtube)

      get "/api/rest/getRandomSongs.view", params: auth_params.merge(size: 500)
      json = JSON.parse(response.body)
      songs = json["subsonic-response"]["randomSongs"]["song"]
      expect(songs.size).to eq(3)
    end

    it "clamps size to valid range" do
      get "/api/rest/getRandomSongs.view", params: auth_params.merge(size: 0)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end
  end

  describe "GET /api/rest/getAlbumList2.view (YouTube filtering)" do
    it "excludes albums where all tracks are YouTube-only" do
      streamable_album = create(:album, title: "Has Audio")
      create(:track, album: streamable_album, artist: streamable_album.artist)

      youtube_album = create(:album, title: "YouTube Only")
      create(:track, :youtube, album: youtube_album, artist: youtube_album.artist)

      get "/api/rest/getAlbumList2.view", params: auth_params
      json = JSON.parse(response.body)
      albums = json["subsonic-response"]["albumList2"]["album"]
      names = albums.map { |a| a["name"] }
      expect(names).to include("Has Audio")
      expect(names).not_to include("YouTube Only")
    end
  end
end
