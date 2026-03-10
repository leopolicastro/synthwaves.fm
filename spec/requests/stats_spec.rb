require "rails_helper"

RSpec.describe "Stats", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /stats" do
    it "returns success" do
      get stats_path
      expect(response).to have_http_status(:ok)
    end

    it "displays summary cards" do
      get stats_path
      expect(response.body).to include("Total Plays")
      expect(response.body).to include("Listening Time")
      expect(response.body).to include("Current Streak")
      expect(response.body).to include("Longest Streak")
    end

    it "displays time range selector" do
      get stats_path
      expect(response.body).to include("Week")
      expect(response.body).to include("Month")
      expect(response.body).to include("Year")
      expect(response.body).to include("All Time")
    end

    it "defaults to month range" do
      get stats_path
      expect(response.body).to include("Listening Stats")
    end

    it "accepts a range parameter" do
      get stats_path(range: :week)
      expect(response).to have_http_status(:ok)
    end

    it "falls back to month for invalid range" do
      get stats_path(range: :invalid)
      expect(response).to have_http_status(:ok)
    end

    context "with play history" do
      let(:artist) { create(:artist, name: "Neon Dreams") }
      let(:album) { create(:album, artist: artist, genre: "Synthwave") }
      let(:track) { create(:track, album: album, artist: artist, title: "Laser Highway") }

      before do
        3.times { create(:play_history, user: user, track: track, played_at: 1.day.ago) }
      end

      it "shows top tracks" do
        get stats_path
        expect(response.body).to include("Laser Highway")
        expect(response.body).to include("Top Tracks")
      end

      it "shows top artists" do
        get stats_path
        expect(response.body).to include("Neon Dreams")
        expect(response.body).to include("Top Artists")
      end

      it "shows top genres" do
        get stats_path
        expect(response.body).to include("Synthwave")
        expect(response.body).to include("Top Genres")
      end

      it "shows play count in summary" do
        get stats_path
        expect(response.body).to include("3")
      end
    end

    context "with no play history" do
      it "shows empty state for tracks" do
        get stats_path
        expect(response.body).to include("No plays yet")
      end
    end

    context "without authentication" do
      it "redirects to login" do
        delete session_path
        get stats_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
