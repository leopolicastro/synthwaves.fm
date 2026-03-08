require "rails_helper"

RSpec.describe "Artists", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /artists" do
    it "returns success" do
      create(:artist)
      get artists_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /artists/:id" do
    it "returns success" do
      artist = create(:artist)
      get artist_path(artist)
      expect(response).to have_http_status(:ok)
    end
  end
end
