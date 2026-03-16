require "rails_helper"

RSpec.describe DatabaseBackupJob, type: :job do
  it "delegates to DatabaseBackupService" do
    allow(DatabaseBackupService).to receive(:call).and_return({key: "backups/db/test.sqlite3.gz", size: 1024})

    described_class.perform_now

    expect(DatabaseBackupService).to have_received(:call)
  end
end
