require "rails_helper"

RSpec.describe "TurboNative", type: :request do
  describe "GET /turbo-native/path-configuration" do
    it "returns 200 with valid JSON" do
      get "/turbo-native/path-configuration"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end

    it "includes settings and rules keys" do
      get "/turbo-native/path-configuration"

      json = response.parsed_body
      expect(json).to have_key("settings")
      expect(json).to have_key("rules")
    end

    it "includes a default rule matching all paths" do
      get "/turbo-native/path-configuration"

      json = response.parsed_body
      rule = json["rules"].first
      expect(rule["patterns"]).to include(".*")
      expect(rule["properties"]["context"]).to eq("default")
    end

    it "does not require authentication" do
      get "/turbo-native/path-configuration"

      expect(response).not_to redirect_to(new_session_path)
      expect(response).to have_http_status(:ok)
    end
  end
end
