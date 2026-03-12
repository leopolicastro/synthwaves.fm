require "rails_helper"

RSpec.describe CoverArtSearchJob, type: :job do
  let(:album) { create(:album) }

  it "calls CoverArtSearchService" do
    expect(CoverArtSearchService).to receive(:call).with(album)
    described_class.perform_now(album)
  end

  it "enqueues in the default queue" do
    expect {
      described_class.perform_later(album)
    }.to have_enqueued_job(described_class).with(album)
  end
end
