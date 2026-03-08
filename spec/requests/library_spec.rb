require "rails_helper"

RSpec.describe "Library", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /library" do
    it "returns success" do
      get library_path
      expect(response).to have_http_status(:ok)
    end

    it "shows library stats" do
      create(:track)
      get library_path
      expect(response.body).to include("Library")
    end
  end
end
