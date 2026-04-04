require "rails_helper"

RSpec.describe API::V1::RadioStationSerializer do
  let(:station) { create(:radio_station) }

  it "returns all fields" do
    result = described_class.render_as_hash(station)
    expect(result).to include(:id, :name, :status, :mount_point, :listen_url,
      :playback_mode, :bitrate, :crossfade_duration, :playlist, :current_track, :created_at)
    expect(result[:playlist]).to include(:id, :name)
    expect(result[:current_track]).to be_nil
  end
end
