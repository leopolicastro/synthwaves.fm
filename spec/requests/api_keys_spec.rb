require "rails_helper"

RSpec.describe "APIKeys", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { login_user(user) }

  describe "GET /api_keys" do
    it "lists the current user's API keys" do
      key = create(:api_key, user: user, name: "My Key")
      create(:api_key, user: other_user, name: "Other Key")

      get api_keys_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Key")
      expect(response.body).not_to include("Other Key")
    end
  end

  describe "GET /api_keys/new" do
    it "renders the new API key form" do
      get new_api_key_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api_keys" do
    it "creates a new API key and shows the secret" do
      expect {
        post api_keys_path, params: { api_key: { name: "Production" } }
      }.to change(APIKey, :count).by(1)

      expect(response).to redirect_to(api_keys_path)
      expect(flash[:api_secret]).to be_present
      expect(flash[:api_secret].length).to eq(64) # 32 hex bytes
    end

    it "assigns the key to the current user" do
      post api_keys_path, params: { api_key: { name: "My Key" } }
      expect(APIKey.last.user).to eq(user)
    end
  end

  describe "DELETE /api_keys/:id" do
    it "revokes the API key" do
      key = create(:api_key, user: user)

      expect {
        delete api_key_path(key)
      }.to change(APIKey, :count).by(-1)

      expect(response).to redirect_to(api_keys_path)
    end

    it "cannot delete another user's key" do
      other_key = create(:api_key, user: other_user)

      delete api_key_path(other_key)
      expect(response).to have_http_status(:not_found)
      expect(APIKey.exists?(other_key.id)).to be true
    end
  end

  describe "authentication" do
    it "requires login to access API keys" do
      reset!
      get api_keys_path
      expect(response).to redirect_to("/session/new")
    end
  end
end
