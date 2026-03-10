require "rails_helper"

RSpec.describe "Subsonic Search API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/search3.view" do
    it "returns matching results" do
      artist = create(:artist, name: "The Beatles")
      album = create(:album, title: "Abbey Road", artist: artist)
      track = create(:track, title: "Come Together", album: album, artist: artist)

      get "/api/rest/search3.view", params: auth_params.merge(query: "Beatles")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["searchResult3"]["artist"]).to be_present
    end

    it "excludes YouTube tracks from song results" do
      artist = create(:artist, name: "Test Artist")
      album = create(:album, title: "Test Album", artist: artist)
      streamable = create(:track, title: "Test Streamable", album: album, artist: artist)
      youtube = create(:track, :youtube, title: "Test YouTube", album: album, artist: artist)

      get "/api/rest/search3.view", params: auth_params.merge(query: "Test")
      json = JSON.parse(response.body)
      songs = json["subsonic-response"]["searchResult3"]["song"]
      titles = songs.map { |s| s["title"] }
      expect(titles).to include("Test Streamable")
      expect(titles).not_to include("Test YouTube")
    end

    it "excludes all-YouTube albums from album results" do
      streamable_album = create(:album, title: "SearchMe Streamable")
      create(:track, album: streamable_album, artist: streamable_album.artist)

      youtube_album = create(:album, title: "SearchMe YouTube")
      create(:track, :youtube, album: youtube_album, artist: youtube_album.artist)

      get "/api/rest/search3.view", params: auth_params.merge(query: "SearchMe")
      json = JSON.parse(response.body)
      albums = json["subsonic-response"]["searchResult3"]["album"]
      names = albums.map { |a| a["name"] }
      expect(names).to include("SearchMe Streamable")
      expect(names).not_to include("SearchMe YouTube")
    end
  end
end
