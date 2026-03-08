require "rails_helper"

RSpec.describe "Static::Landing", type: :request do
  describe "GET /" do
    context "when not authenticated" do
      it "returns http success" do
        get root_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when authenticated" do
      let(:user) { User.create!(email_address: "test@example.com", password: "password123") }

      before do
        post session_path, params: {email_address: user.email_address, password: "password123"}
      end

      it "redirects to library" do
        get root_path
        expect(response).to redirect_to(library_path)
      end
    end
  end
end
