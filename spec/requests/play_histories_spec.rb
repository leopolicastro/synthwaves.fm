require "rails_helper"

RSpec.describe "PlayHistories", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /play_histories" do
    it "returns success" do
      get play_histories_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /play_histories" do
    let(:track) { create(:track) }

    it "records a play" do
      expect {
        post play_histories_path, params: {track_id: track.id}, as: :json
      }.to change(PlayHistory, :count).by(1)
    end

    it "returns not found for nonexistent track" do
      post play_histories_path, params: {track_id: 99999}, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
