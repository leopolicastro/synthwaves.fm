require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /search" do
    it "returns success without query" do
      get search_path
      expect(response).to have_http_status(:ok)
    end

    it "returns matching results" do
      artist = create(:artist, name: "The Beatles")
      get search_path, params: {q: "Beatles"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The Beatles")
    end
  end
end
