require "rails_helper"

RSpec.describe "Static::Privacy", type: :request do
  describe "GET /privacy" do
    before { get privacy_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "displays the privacy policy content" do
      expect(response.body).to include("Privacy Policy")
      expect(response.body).to include("Information We Collect")
      expect(response.body).to include("privacy@synthwaves.fm")
    end

    it "is accessible without authentication" do
      expect(response).not_to redirect_to(new_session_path)
    end
  end
end
