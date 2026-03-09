require "rails_helper"

RSpec.describe "API Import Direct Uploads", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({ user_id: user.id, api_key_id: api_key.id }) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/import/direct_uploads" do
    let(:valid_params) do
      {
        filename: "test_video.mp4",
        byte_size: 1024,
        checksum: Base64.strict_encode64(Digest::MD5.digest("test")),
        content_type: "video/mp4"
      }
    end

    it "creates a blob and returns a presigned upload URL" do
      expect {
        post api_import_direct_uploads_path, params: valid_params, headers: auth_headers
      }.to change(ActiveStorage::Blob, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["signed_id"]).to be_present
      expect(json["direct_upload"]["url"]).to be_present
      expect(json["direct_upload"]["headers"]).to be_a(Hash)
    end

    it "defaults content_type to video/mp4" do
      post api_import_direct_uploads_path,
        params: valid_params.except(:content_type),
        headers: auth_headers

      expect(response).to have_http_status(:created)
      blob = ActiveStorage::Blob.last
      expect(blob.content_type).to eq("video/mp4")
    end

    it "returns unprocessable_entity with missing params" do
      post api_import_direct_uploads_path,
        params: { filename: "test.mp4" },
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns unauthorized without valid credentials" do
      post api_import_direct_uploads_path,
        params: valid_params,
        headers: { "Authorization" => "Bearer invalid" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized without any credentials" do
      post api_import_direct_uploads_path, params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
