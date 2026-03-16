require "rails_helper"

RSpec.describe "Music", type: :request do
  describe "GET /music" do
    it "requires authentication" do
      get music_path
      expect(response).to redirect_to(new_session_path)
    end

    it "defaults to artists tab" do
      user = create(:user)
      login_user(user)
      get music_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Music")
    end

    it "renders the artists tab" do
      user = create(:user)
      login_user(user)
      create(:artist, name: "Test Artist", category: :music, user: user)

      get music_path(tab: "artists")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test Artist")
    end

    it "renders the albums tab" do
      user = create(:user)
      login_user(user)
      artist = create(:artist, category: :music, user: user)
      create(:album, title: "Test Album", artist: artist)

      get music_path(tab: "albums")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test Album")
    end

    it "renders the tracks tab" do
      user = create(:user)
      login_user(user)
      artist = create(:artist, category: :music, user: user)
      album = create(:album, artist: artist)
      create(:track, title: "Test Track", artist: artist, album: album)

      get music_path(tab: "tracks")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test Track")
    end

    it "falls back to artists for invalid tab" do
      user = create(:user)
      login_user(user)
      get music_path(tab: "invalid")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Search artists...")
    end

    it "renders the playlists tab" do
      user = create(:user)
      login_user(user)
      create(:playlist, name: "My Chill Mix", user: user)

      get music_path(tab: "playlists")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Chill Mix")
    end

    it "does not show other users' playlists" do
      user = create(:user)
      other_user = create(:user)
      login_user(user)
      create(:playlist, name: "Secret Playlist", user: other_user)

      get music_path(tab: "playlists")

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Secret Playlist")
    end

    it "renders the radio tab when feature is enabled" do
      user = create(:user)
      Flipper.enable(:youtube_radio, user)
      login_user(user)
      create(:radio_station, name: "Lofi Beats", user: user)

      get music_path(tab: "radio")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Lofi Beats")
    end

    it "falls back to artists when radio feature is disabled" do
      user = create(:user)
      login_user(user)

      get music_path(tab: "radio")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Search artists...")
    end

    it "renders the internet radio tab when feature is enabled" do
      user = create(:user)
      Flipper.enable(:internet_radio, user)
      login_user(user)
      create(:internet_radio_station, name: "Jazz FM")

      get music_path(tab: "internet_radio")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Jazz FM")
    end

    it "falls back to artists when internet radio feature is disabled" do
      user = create(:user)
      login_user(user)

      get music_path(tab: "internet_radio")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Search artists...")
    end

    it "shows radio tab link when feature is enabled" do
      user = create(:user)
      Flipper.enable(:youtube_radio, user)
      login_user(user)

      get music_path

      expect(response.body).to include(">Radio</a>")
    end

    it "hides radio tab link when feature is disabled" do
      user = create(:user)
      login_user(user)

      get music_path

      expect(response.body).not_to include(">Radio</a>")
    end

    it "shows internet radio tab link when feature is enabled" do
      user = create(:user)
      Flipper.enable(:internet_radio, user)
      login_user(user)

      get music_path

      expect(response.body).to include(">Internet Radio</a>")
    end

    it "hides internet radio tab link when feature is disabled" do
      user = create(:user)
      login_user(user)

      get music_path

      expect(response.body).not_to include(">Internet Radio</a>")
    end

    it "always shows the playlists tab link" do
      user = create(:user)
      login_user(user)

      get music_path

      expect(response.body).to include(">Playlists</a>")
    end
  end
end
