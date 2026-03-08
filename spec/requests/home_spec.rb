require "rails_helper"

RSpec.describe "Homes", type: :request do
  describe "GET /home" do
    it "returns http success" do
      user = create(:user)
      login_user(user)

      get "/home"
      expect(response).to have_http_status(:success)
    end
  end
end
