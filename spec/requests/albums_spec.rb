require "rails_helper"

RSpec.describe "Albums", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /albums" do
    it "returns success" do
      create(:album)
      get albums_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /albums/:id" do
    it "returns success" do
      album = create(:album)
      get album_path(album)
      expect(response).to have_http_status(:ok)
    end
  end
end
