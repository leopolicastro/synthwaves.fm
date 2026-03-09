require "rails_helper"

RSpec.describe "Visualizer", type: :request do
  describe "GET /visualizer" do
    context "when authenticated" do
      let(:user) { create(:user) }

      before { login_user(user) }

      it "returns success" do
        get visualizer_path
        expect(response).to have_http_status(:ok)
      end

      it "renders the visualizer Stimulus controller" do
        get visualizer_path
        expect(response.body).to include('data-controller="visualizer"')
      end

      it "renders the canvas target" do
        get visualizer_path
        expect(response.body).to include('data-visualizer-target="canvas"')
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get visualizer_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
