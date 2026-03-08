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

  describe "GET /api/rest/scrobble.view" do
    it "records play history" do
      track = create(:track)

      expect {
        get "/api/rest/scrobble.view", params: auth_params.merge(id: track.id)
      }.to change(PlayHistory, :count).by(1)
    end
  end
end
