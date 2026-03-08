require "rails_helper"

RSpec.describe "Subsonic Lists API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/getAlbumList2.view" do
    let!(:album_a) { create(:album, title: "Alpha", year: 2020, genre: "Rock") }
    let!(:album_b) { create(:album, title: "Beta", year: 2022, genre: "Jazz") }

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

    it "clamps size to valid range" do
      get "/api/rest/getRandomSongs.view", params: auth_params.merge(size: 0)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end
  end
end
