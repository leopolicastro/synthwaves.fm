require "rails_helper"

RSpec.describe EPGSyncJob, type: :job do
  it "delegates to EPGSyncService" do
    allow(EPGSyncService).to receive(:call).and_return({synced: 10, channels: 5})

    described_class.perform_now

    expect(EPGSyncService).to have_received(:call)
  end
end
