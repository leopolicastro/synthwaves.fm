require "rails_helper"

RSpec.describe "API::V1::Taggings", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }

  describe "POST /api/v1/taggings" do
    it "creates a tagging with a new tag" do
      track = create(:track, artist: artist, album: album, user: user)

      expect {
        post "/api/v1/taggings", params: {
          name: "Synthwave", tag_type: "genre",
          taggable_type: "Track", taggable_id: track.id
        }, headers: auth_headers
      }.to change(Tagging, :count).by(1)
        .and change(Tag, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["tag"]["name"]).to eq("synthwave") # downcased
      expect(json["taggable_type"]).to eq("Track")
    end

    it "reuses an existing tag" do
      create(:tag, name: "synthwave", tag_type: "genre")
      track = create(:track, artist: artist, album: album, user: user)

      expect {
        post "/api/v1/taggings", params: {
          name: "Synthwave", tag_type: "genre",
          taggable_type: "Track", taggable_id: track.id
        }, headers: auth_headers
      }.to change(Tag, :count).by(0)

      expect(response).to have_http_status(:created)
    end

    it "rejects invalid taggable_type" do
      post "/api/v1/taggings", params: {
        name: "test", tag_type: "genre",
        taggable_type: "Invalid", taggable_id: 1
      }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/v1/taggings/:id" do
    it "deletes a tagging" do
      track = create(:track, artist: artist, album: album, user: user)
      tag = create(:tag, name: "synthwave", tag_type: "genre")
      tagging = create(:tagging, user: user, tag: tag, taggable: track)

      expect {
        delete "/api/v1/taggings/#{tagging.id}", headers: auth_headers
      }.to change(Tagging, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for another user's tagging" do
      other_tagging = create(:tagging)

      delete "/api/v1/taggings/#{other_tagging.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
