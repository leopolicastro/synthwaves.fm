require "rails_helper"

RSpec.describe "SmartPlaylists", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /smart-playlists" do
    it "returns success" do
      get smart_playlists_path
      expect(response).to have_http_status(:ok)
    end

    it "shows all smart playlist definitions" do
      get smart_playlists_path
      SmartPlaylistService::DEFINITIONS.each_value do |definition|
        expect(response.body).to include(definition[:name])
      end
    end
  end

  describe "GET /smart-playlists/:id" do
    it "returns success for a valid playlist" do
      get smart_playlist_path(:most_played)
      expect(response).to have_http_status(:ok)
    end

    it "shows playlist name and description" do
      get smart_playlist_path(:recently_added)
      expect(response.body).to include("Recently Added")
      expect(response.body).to include("Tracks added in the last 30 days")
    end

    it "shows tracks when they exist" do
      track = create(:track, title: "Neon Highway")
      3.times { create(:play_history, user: user, track: track) }

      get smart_playlist_path(:most_played)
      expect(response.body).to include("Neon Highway")
    end

    it "shows empty state when no tracks match" do
      get smart_playlist_path(:heavy_rotation)
      expect(response.body).to include("No tracks match this playlist yet")
    end

    it "redirects for invalid playlist id" do
      get smart_playlist_path(:nonexistent)
      expect(response).to redirect_to(smart_playlists_path)
    end

    context "without authentication" do
      it "redirects to login" do
        delete session_path
        get smart_playlists_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
