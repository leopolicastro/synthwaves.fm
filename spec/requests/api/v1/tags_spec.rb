require "rails_helper"

RSpec.describe "API::V1::Tags", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  describe "GET /api/v1/tags" do
    it "returns all tags" do
      create(:tag, name: "synthwave", tag_type: "genre")
      create(:tag, name: "chill", tag_type: "mood")

      get "/api/v1/tags", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tags"].length).to eq(2)
    end

    it "filters by type" do
      create(:tag, name: "synthwave", tag_type: "genre")
      create(:tag, name: "chill", tag_type: "mood")

      get "/api/v1/tags", params: {type: "genre"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["tags"].length).to eq(1)
      expect(json["tags"].first["name"]).to eq("synthwave")
    end

    it "searches by name prefix" do
      create(:tag, name: "synthwave", tag_type: "genre")
      create(:tag, name: "synthpop", tag_type: "genre")
      create(:tag, name: "jazz", tag_type: "genre")

      get "/api/v1/tags", params: {q: "synth"}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["tags"].length).to eq(2)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/tags"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
