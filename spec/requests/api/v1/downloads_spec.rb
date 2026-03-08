require "rails_helper"

RSpec.describe "API::V1::Downloads", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:headers) { {"Authorization" => "Bearer #{token}"} }

  describe "POST /api/v1/downloads" do
    before do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:trafi, :base_url).and_return("http://192.168.1.67:8000")
      allow(Rails.application.credentials).to receive(:dig).with(:trafi, :api_key).and_return("test-key")
      allow(Rails.application.credentials).to receive(:dig).with(:trafi, :webhook_host).and_return("localhost:3000")
    end

    context "with a URL" do
      it "creates a download and returns 202" do
        stub_request(:post, "http://192.168.1.67:8000/download/url")
          .to_return(status: 200, body: {total_tracks: 1}.to_json)

        post "/api/v1/downloads", params: {url: "https://youtube.com/watch?v=abc"}, headers: headers

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body["job_id"]).to be_present
        expect(body["status"]).to eq("queued")
      end
    end

    context "with a query" do
      it "creates a search download and returns 202" do
        stub_request(:post, "http://192.168.1.67:8000/download/search")
          .to_return(status: 200, body: {total_tracks: 1}.to_json)

        post "/api/v1/downloads", params: {query: "Daft Punk Get Lucky"}, headers: headers

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body["job_id"]).to be_present
      end
    end

    context "without url or query" do
      it "returns 422" do
        post "/api/v1/downloads", params: {}, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/downloads", params: {url: "https://youtube.com/watch?v=abc"}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
