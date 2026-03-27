require "rails_helper"

RSpec.describe StationListenerSyncJob, type: :job do
  let(:user) { create(:user) }

  describe "#perform" do
    it "updates listener counts from Icecast stats" do
      playlist = create(:playlist, user: user)
      station = create(:radio_station,
        playlist: playlist,
        user: user,
        status: "active",
        mount_point: "/chill.mp3",
        listener_count: 0)

      icecast_response = {
        "icestats" => {
          "source" => {
            "listenurl" => "http://localhost:8000/chill.mp3",
            "listeners" => 3
          }
        }
      }

      stub_request(:get, %r{status-json\.xsl})
        .to_return(status: 200, body: icecast_response.to_json, headers: {"Content-Type" => "application/json"})

      StationListenerSyncJob.perform_now

      expect(station.reload.listener_count).to eq(3)
    end

    it "handles multiple mount points" do
      playlist1 = create(:playlist, user: user)
      station1 = create(:radio_station, playlist: playlist1, user: user, status: "active", mount_point: "/a.mp3", listener_count: 0)
      playlist2 = create(:playlist, user: user)
      station2 = create(:radio_station, playlist: playlist2, user: user, status: "active", mount_point: "/b.mp3", listener_count: 0)

      icecast_response = {
        "icestats" => {
          "source" => [
            {"listenurl" => "http://localhost:8000/a.mp3", "listeners" => 2},
            {"listenurl" => "http://localhost:8000/b.mp3", "listeners" => 0}
          ]
        }
      }

      stub_request(:get, %r{status-json\.xsl})
        .to_return(status: 200, body: icecast_response.to_json, headers: {"Content-Type" => "application/json"})

      StationListenerSyncJob.perform_now

      expect(station1.reload.listener_count).to eq(2)
      expect(station2.reload.listener_count).to eq(0)
    end

    it "handles Icecast being unavailable" do
      playlist = create(:playlist, user: user)
      create(:radio_station, playlist: playlist, user: user, status: "active", listener_count: 5)

      stub_request(:get, %r{status-json\.xsl}).to_raise(Errno::ECONNREFUSED)

      expect {
        StationListenerSyncJob.perform_now
      }.not_to raise_error
    end

    it "skips when no active stations" do
      expect {
        StationListenerSyncJob.perform_now
      }.not_to raise_error
    end
  end
end
