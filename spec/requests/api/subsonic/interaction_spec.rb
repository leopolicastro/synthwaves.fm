require "rails_helper"

RSpec.describe "Subsonic Interaction API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/star.view" do
    it "stars a track" do
      track = create(:track)

      expect {
        get "/api/rest/star.view", params: auth_params.merge(id: track.id)
      }.to change(Favorite, :count).by(1)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end

    it "ignores nonexistent track IDs without creating dangling favorites" do
      expect {
        get "/api/rest/star.view", params: auth_params.merge(id: 99999)
      }.not_to change(Favorite, :count)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end

    it "stars an album via albumId" do
      album = create(:album)

      expect {
        get "/api/rest/star.view", params: auth_params.merge(albumId: album.id)
      }.to change(Favorite, :count).by(1)

      fav = user.favorites.last
      expect(fav.favorable).to eq(album)
    end

    it "stars an artist via artistId" do
      artist = create(:artist)

      expect {
        get "/api/rest/star.view", params: auth_params.merge(artistId: artist.id)
      }.to change(Favorite, :count).by(1)

      fav = user.favorites.last
      expect(fav.favorable).to eq(artist)
    end
  end

  describe "GET /api/rest/unstar.view" do
    it "unstars a track" do
      track = create(:track)
      create(:favorite, user: user, favorable: track)

      expect {
        get "/api/rest/unstar.view", params: auth_params.merge(id: track.id)
      }.to change(Favorite, :count).by(-1)
    end

    it "unstars an album via albumId" do
      album = create(:album)
      create(:favorite, user: user, favorable: album)

      expect {
        get "/api/rest/unstar.view", params: auth_params.merge(albumId: album.id)
      }.to change(Favorite, :count).by(-1)
    end

    it "unstars an artist via artistId" do
      artist = create(:artist)
      create(:favorite, user: user, favorable: artist)

      expect {
        get "/api/rest/unstar.view", params: auth_params.merge(artistId: artist.id)
      }.to change(Favorite, :count).by(-1)
    end
  end

  describe "GET /api/rest/getStarred2.view" do
    it "returns empty arrays when nothing is starred" do
      get "/api/rest/getStarred2.view", params: auth_params
      json = JSON.parse(response.body)
      starred = json["subsonic-response"]["starred2"]
      expect(starred["artist"]).to eq([])
      expect(starred["album"]).to eq([])
      expect(starred["song"]).to eq([])
    end

    it "returns starred artists, albums, and songs" do
      artist = create(:artist)
      album = create(:album, artist: artist)
      track = create(:track, album: album, artist: artist)

      create(:favorite, user: user, favorable: artist)
      create(:favorite, user: user, favorable: album)
      create(:favorite, user: user, favorable: track)

      get "/api/rest/getStarred2.view", params: auth_params
      json = JSON.parse(response.body)
      starred = json["subsonic-response"]["starred2"]

      expect(starred["artist"].size).to eq(1)
      expect(starred["artist"].first["name"]).to eq(artist.name)
      expect(starred["artist"].first["starred"]).to be_present

      expect(starred["album"].size).to eq(1)
      expect(starred["album"].first["name"]).to eq(album.title)
      expect(starred["album"].first["starred"]).to be_present

      expect(starred["song"].size).to eq(1)
      expect(starred["song"].first["title"]).to eq(track.title)
      expect(starred["song"].first["starred"]).to be_present
    end

    it "does not return other users' starred items" do
      other = create(:user)
      track = create(:track)
      create(:favorite, user: other, favorable: track)

      get "/api/rest/getStarred2.view", params: auth_params
      json = JSON.parse(response.body)
      starred = json["subsonic-response"]["starred2"]
      expect(starred["song"]).to eq([])
    end
  end

  describe "GET /api/rest/scrobble.view" do
    it "records play history" do
      track = create(:track)

      expect {
        get "/api/rest/scrobble.view", params: auth_params.merge(id: track.id)
      }.to change(PlayHistory, :count).by(1)
    end
  end
end
