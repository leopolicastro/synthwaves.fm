require "rails_helper"

RSpec.describe ChatResponseJob, type: :job do
  it "finds the chat and calls ask with the content" do
    chat = instance_double(Chat)
    allow(Chat).to receive(:find).with(42).and_return(chat)
    expect(chat).to receive(:ask).with("Hello")

    described_class.perform_now(42, "Hello")
  end
end
