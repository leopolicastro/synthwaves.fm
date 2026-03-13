require "rails_helper"

RSpec.describe "TV", type: :request do
  describe "GET /tv" do
    it "renders the podcasts tab with podcast artists" do
      user = create(:user)
      login_user(user)
      create(:artist, :podcast, name: "My Great Podcast", user: user)

      get tv_path(tab: "podcasts")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Great Podcast")
    end

    it "does not show music artists in the podcasts tab" do
      user = create(:user)
      login_user(user)
      create(:artist, name: "Music Only Band", category: :music, user: user)

      get tv_path(tab: "podcasts")

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Music Only Band")
    end
  end
end
