require "rails_helper"

RSpec.describe "Recommendations", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /recommendations" do
    before do
      # Ensure at least one model exists for chat creation
      Model.find_or_create_by!(model_id: "gpt-4o-mini") do |m|
        m.name = "GPT-4o Mini"
        m.provider = "openai"
      end
    end

    it "returns success" do
      get recommendations_path
      expect(response).to have_http_status(:ok)
    end

    it "creates a chat" do
      expect { get recommendations_path }.to change(Chat, :count).by(1)
    end

    it "enqueues a ChatResponseJob" do
      expect {
        get recommendations_path
      }.to have_enqueued_job(ChatResponseJob)
    end

    it "renders the DJ view" do
      get recommendations_path
      expect(response.body).to include("DJ Synth")
      expect(response.body).to include("AI-powered music recommendations")
    end

    context "without authentication" do
      it "redirects to login" do
        delete session_path
        get recommendations_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
