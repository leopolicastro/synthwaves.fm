require "rails_helper"

RSpec.describe "Favorites", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /favorites" do
    it "returns success" do
      get favorites_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /favorites" do
    it "creates a favorite for a Track" do
      track = create(:track, album: create(:album, artist: create(:artist, user: user)))
      expect {
        post favorites_path, params: {favorable_type: "Track", favorable_id: track.id}
      }.to change(Favorite, :count).by(1)
    end

    it "creates a favorite for an Album" do
      album = create(:album, artist: create(:artist, user: user))
      expect {
        post favorites_path, params: {favorable_type: "Album", favorable_id: album.id}
      }.to change(Favorite, :count).by(1)
    end

    it "creates a favorite for an Artist" do
      artist = create(:artist, user: user)
      expect {
        post favorites_path, params: {favorable_type: "Artist", favorable_id: artist.id}
      }.to change(Favorite, :count).by(1)
    end

    it "creates a favorite for an IPTVChannel" do
      channel = create(:iptv_channel)
      expect {
        post favorites_path, params: {favorable_type: "IPTVChannel", favorable_id: channel.id}
      }.to change(Favorite, :count).by(1)
    end

    it "creates a favorite for an InternetRadioStation" do
      station = create(:internet_radio_station)
      expect {
        post favorites_path, params: {favorable_type: "InternetRadioStation", favorable_id: station.id}
      }.to change(Favorite, :count).by(1)
    end

    it "is idempotent for the same favorable" do
      track = create(:track, album: create(:album, artist: create(:artist, user: user)))
      post favorites_path, params: {favorable_type: "Track", favorable_id: track.id}
      expect {
        post favorites_path, params: {favorable_type: "Track", favorable_id: track.id}
      }.not_to change(Favorite, :count)
    end

    it "returns not found for invalid favorable_type" do
      post favorites_path, params: {favorable_type: "User", favorable_id: user.id}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /favorites/:id" do
    let(:track) { create(:track, album: create(:album, artist: create(:artist, user: user))) }
    let!(:favorite) { create(:favorite, user: user, favorable: track) }

    it "removes the favorite" do
      expect {
        delete favorite_path(favorite)
      }.to change(Favorite, :count).by(-1)
    end
  end
end
