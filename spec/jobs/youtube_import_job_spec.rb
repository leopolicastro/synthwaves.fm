require "rails_helper"

RSpec.describe YoutubeImportJob, type: :job do
  let(:user) { create(:user, youtube_api_key: "test_api_key") }

  it "calls YoutubePlaylistImportService with the url, category, and user api_key" do
    allow(YoutubePlaylistImportService).to receive(:call)

    described_class.perform_now(
      "https://www.youtube.com/playlist?list=PLtest123",
      category: "podcast",
      user_id: user.id
    )

    expect(YoutubePlaylistImportService).to have_received(:call)
      .with("https://www.youtube.com/playlist?list=PLtest123", category: "podcast", api_key: "test_api_key", user: user)
  end
end
