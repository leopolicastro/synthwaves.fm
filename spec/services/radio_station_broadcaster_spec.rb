require "rails_helper"

RSpec.describe RadioStationBroadcaster do
  let(:station) { create(:radio_station) }

  describe ".status" do
    it "broadcasts to private and public channels" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("radio_stations_#{station.user_id}", target: "radio_station_#{station.id}", partial: "radio_stations/station", locals: {station: station})
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("radio_station_public_#{station.id}", target: "public_status_#{station.id}", partial: "radio_stations/status_badge", locals: {station: station})

      described_class.status(station)
    end
  end

  describe ".now_playing" do
    it "broadcasts to private and public channels" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("radio_stations_#{station.user_id}", target: "now_playing_#{station.id}", partial: "radio_stations/now_playing", locals: {station: station})
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("radio_station_public_#{station.id}", target: "now_playing_#{station.id}", partial: "radio_stations/now_playing", locals: {station: station})

      described_class.now_playing(station)
    end
  end

  describe ".queue" do
    it "broadcasts to public channel" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("radio_station_public_#{station.id}", target: "station_queue_#{station.id}", partial: "public_radio_stations/queue", locals: hash_including(station: station))

      described_class.queue(station)
    end
  end
end
