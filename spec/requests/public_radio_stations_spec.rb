require "rails_helper"

RSpec.describe "PublicRadioStations", type: :request do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:station) { create(:radio_station, playlist: playlist, user: user, mount_point: "/chill-vibes.mp3") }

  describe "GET /radio" do
    it "redirects unauthenticated users to login" do
      get public_radio_stations_path
      expect(response).to redirect_to(new_session_path)
    end

    context "when authenticated" do
      before { login_user(user) }

      it "returns success" do
        get public_radio_stations_path
        expect(response).to have_http_status(:ok)
      end

      it "shows active stations" do
        station.update!(status: "active")
        get public_radio_stations_path
        expect(response.body).to include(public_radio_station_path(slug: station.slug))
      end

      it "excludes stopped stations" do
        station # default status is stopped
        get public_radio_stations_path
        expect(response.body).not_to include(public_radio_station_path(slug: station.slug))
      end

      it "shows empty state when no stations are live" do
        get public_radio_stations_path
        expect(response.body).to include("No stations on air")
      end
    end
  end

  describe "GET /radio/:slug" do
    it "redirects unauthenticated users to login" do
      get public_radio_station_path(slug: station.slug)
      expect(response).to redirect_to(new_session_path)
    end

    context "when authenticated" do
      before { login_user(user) }

      it "returns success for a valid station slug" do
        get public_radio_station_path(slug: station.slug)
        expect(response).to have_http_status(:ok)
      end

      it "renders the station name" do
        get public_radio_station_path(slug: station.slug)
        expect(response.body).to include(playlist.name)
      end

      it "returns 404 for an invalid slug" do
        get public_radio_station_path(slug: "nonexistent")
        expect(response).to have_http_status(:not_found)
      end

      it "shows station details" do
        get public_radio_station_path(slug: station.slug)
        expect(response.body).to include(station.bitrate.to_s)
      end

      context "when station is active with a current track" do
        let(:track) { create(:track) }

        before do
          station.update!(status: "active", current_track: track)
        end

        it "shows the listen button" do
          get public_radio_station_path(slug: station.slug)
          expect(response.body).to include("Listen Live")
        end

        it "shows the current track" do
          get public_radio_station_path(slug: station.slug)
          expect(response.body).to include(track.title)
        end

        it "shows upcoming tracks in the queue" do
          upcoming = create(:track, title: "Upcoming Jam")
          create(:radio_queue_track, radio_station: station, track: upcoming, position: 1)

          get public_radio_station_path(slug: station.slug)
          expect(response.body).to include("Upcoming Jam")
          expect(response.body).to include("Up Next")
        end

        it "shows recently played tracks" do
          # The 2 most recent played entries are current/queued tracks (skipped by offset)
          create(:radio_queue_track, :played, radio_station: station, track: create(:track), played_at: 10.seconds.ago)
          create(:radio_queue_track, :played, radio_station: station, track: create(:track), played_at: 30.seconds.ago)
          # This one has actually finished playing
          played = create(:track, title: "Old Favorite")
          create(:radio_queue_track, :played, radio_station: station, track: played, played_at: 1.minute.ago)

          get public_radio_station_path(slug: station.slug)
          expect(response.body).to include("Old Favorite")
          expect(response.body).to include("Recently Played")
        end
      end

      context "when station is stopped" do
        it "shows offline state" do
          get public_radio_station_path(slug: station.slug)
          expect(response.body).to include("Station Offline")
        end
      end

      context "when station is active" do
        it "shows the stream URL with a copy button" do
          station.update!(status: :active)
          get public_radio_station_path(slug: station.slug)
          expect(response.body).to include(station.listen_url)
          expect(response.body).to include("Stream URL")
        end
      end
    end
  end
end
