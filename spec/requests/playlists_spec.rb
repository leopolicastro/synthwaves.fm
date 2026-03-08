require "rails_helper"

RSpec.describe "Playlists", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /playlists" do
    it "returns success" do
      get playlists_path
      expect(response).to have_http_status(:ok)
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
  end

  describe "PATCH /playlists/:id" do
    let(:playlist) { create(:playlist, user: user) }

    it "updates the playlist" do
      patch playlist_path(playlist), params: {playlist: {name: "Updated"}}
      expect(playlist.reload.name).to eq("Updated")
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
