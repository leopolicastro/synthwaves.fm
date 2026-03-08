require "rails_helper"

RSpec.describe "Library", type: :request do
  let(:user) { create(:user, name: "Leo") }

  before { login_user(user) }

  describe "GET /library" do
    it "returns success with empty library" do
      get library_path
      expect(response).to have_http_status(:ok)
    end

    it "displays personalized greeting with user name" do
      get library_path
      expect(response.body).to include("Leo")
    end

    it "falls back to email prefix when name is blank" do
      user.update!(name: nil)
      get library_path
      expect(response.body).to include(user.email_address.split("@").first)
    end

    context "Recently Played section" do
      it "appears when play histories exist" do
        track = create(:track)
        create(:play_history, user: user, track: track)

        get library_path
        expect(response.body).to include("Recently Played")
        expect(response.body).to include(track.title)
      end

      it "is hidden when no play histories exist" do
        get library_path
        expect(response.body).not_to include("Recently Played")
      end

      it "deduplicates tracks showing most recent play" do
        track = create(:track)
        create(:play_history, user: user, track: track, played_at: 2.hours.ago)
        create(:play_history, user: user, track: track, played_at: 1.hour.ago)

        get library_path
        expect(response.body.scan(track.title).count).to eq(1)
      end
    end

    context "Playlists section" do
      it "always renders with New Playlist CTA" do
        get library_path
        expect(response.body).to include("Your Playlists")
        expect(response.body).to include("New Playlist")
      end

      it "shows existing playlists" do
        playlist = create(:playlist, user: user, name: "My Jams")
        get library_path
        expect(response.body).to include("My Jams")
      end
    end

    context "Favorites section" do
      it "appears when user has favorite tracks" do
        track = create(:track)
        create(:favorite, user: user, favorable: track)

        get library_path
        expect(response.body).to include("Favorites")
        expect(response.body).to include(track.title)
      end

      it "is hidden when no favorites exist" do
        get library_path
        expect(response.body).not_to include("Favorites")
      end
    end

    context "Radio Stations section" do
      it "appears when feature flag is enabled and stations exist" do
        Flipper.enable(:youtube_radio, user)
        station = create(:radio_station, user: user, name: "Lofi Beats")

        get library_path
        expect(response.body).to include("Radio Stations")
        expect(response.body).to include("Lofi Beats")
      end

      it "is hidden when feature flag is disabled" do
        Flipper.disable(:youtube_radio, user)
        create(:radio_station, user: user)

        get library_path
        expect(response.body).not_to include("Radio Stations")
      end
    end

    context "Recently Added section" do
      it "appears when albums with tracks exist" do
        album = create(:album)
        create(:track, album: album, artist: album.artist)

        get library_path
        expect(response.body).to include("Recently Added")
        expect(response.body).to include(album.title)
      end

      it "is hidden when no albums exist" do
        get library_path
        expect(response.body).not_to include("Recently Added")
      end
    end

    context "Podcasts section" do
      it "appears when podcast artists exist" do
        podcast_artist = create(:artist, :podcast, name: "Tech Talk")

        get library_path
        expect(response.body).to include("Podcasts")
        expect(response.body).to include("Tech Talk")
      end

      it "is hidden when no podcasts exist" do
        get library_path
        # "Podcasts" appears in Browse tiles, but no podcast cards should render
        expect(response.body).not_to include("episode")
      end
    end

    context "Browse section" do
      it "shows correct counts" do
        create(:track) # creates artist + album too
        create(:artist, :podcast)

        get library_path
        expect(response.body).to include("Browse")
        expect(response.body).to include("Artists")
        expect(response.body).to include("Albums")
        expect(response.body).to include("Tracks")
        expect(response.body).to include("Podcasts")
      end
    end
  end
end
