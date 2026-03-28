require "rails_helper"

RSpec.describe StationControlJob, type: :job do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }

  describe "#perform" do
    context "when radio_stations feature is disabled" do
      before { Flipper.disable(:radio_stations) }

      it "returns early without performing any station operations" do
        station = create(:radio_station, playlist: playlist, user: user, status: "starting")

        StationControlJob.perform_now(station.id, "start")

        expect(station.reload.status).to eq("starting")
      end
    end

    context "when radio_stations feature is enabled" do
      before { Flipper.enable(:radio_stations) }

      it "starts a station" do
        station = create(:radio_station, playlist: playlist, user: user, status: "starting")

        allow(LiquidsoapConfigService).to receive(:call)

        StationControlJob.perform_now(station.id, "start")

        expect(station.reload.status).to eq("active")
        expect(LiquidsoapConfigService).to have_received(:call)
      end

      it "stops a station" do
        station = create(:radio_station, playlist: playlist, user: user, status: "active")

        allow(LiquidsoapConfigService).to receive(:call)

        StationControlJob.perform_now(station.id, "stop")

        expect(station.reload.status).to eq("stopped")
        expect(LiquidsoapConfigService).to have_received(:call)
      end

      it "skips to the next track" do
        station = create(:radio_station, playlist: playlist, user: user, status: "active")

        allow(NextTrackService).to receive(:call).and_return(nil)

        StationControlJob.perform_now(station.id, "skip")

        expect(NextTrackService).to have_received(:call).with(station)
      end

      it "handles missing station gracefully" do
        expect {
          StationControlJob.perform_now(999_999, "start")
        }.not_to raise_error
      end

      it "sets error status on failure during start" do
        station = create(:radio_station, playlist: playlist, user: user, status: "starting")

        allow(LiquidsoapConfigService).to receive(:call).and_raise(RuntimeError, "Config write failed")

        StationControlJob.perform_now(station.id, "start")

        expect(station.reload.status).to eq("error")
        expect(station.error_message).to eq("Config write failed")
      end
    end
  end
end
