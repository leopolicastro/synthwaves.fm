require "rails_helper"

RSpec.describe "TV", type: :request do
  describe "GET /tv" do
    before do
      Flipper.enable(:iptv)
    end

    it "renders the podcasts tab with podcast artists" do
      login_user(create(:user))
      create(:artist, :podcast, name: "My Great Podcast")

      get tv_path(tab: "podcasts")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Great Podcast")
    end

    it "does not show music artists in the podcasts tab" do
      login_user(create(:user))
      create(:artist, name: "Music Only Band", category: :music)

      get tv_path(tab: "podcasts")

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Music Only Band")
    end
  end
end
