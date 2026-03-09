require "rails_helper"

RSpec.describe "API Import Videos", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({ user_id: user.id, api_key_id: api_key.id }) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/import/videos" do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake video data"),
        filename: "test_video.mp4",
        content_type: "video/mp4"
      )
    end

    it "creates a video from a signed blob ID" do
      expect {
        post api_import_videos_path,
          params: { signed_blob_id: blob.signed_id, title: "My Video" },
          headers: auth_headers
      }.to change(Video, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present
      expect(json["title"]).to eq("My Video")
      expect(json["folder"]).to be_nil
      expect(json["status"]).to eq("processing")
    end

    it "defaults title to blob filename" do
      post api_import_videos_path,
        params: { signed_blob_id: blob.signed_id },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("test_video")
    end

    it "creates a video with folder" do
      post api_import_videos_path,
        params: {
          signed_blob_id: blob.signed_id,
          title: "Episode 1",
          folder_name: "My Show",
          season_number: 1,
          episode_number: 1
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["folder"]).to eq("My Show")

      video = Video.last
      expect(video.folder.name).to eq("My Show")
      expect(video.season_number).to eq(1)
      expect(video.episode_number).to eq(1)
    end

    it "reuses existing folder" do
      folder = create(:folder, user: user, name: "Existing Show")

      expect {
        post api_import_videos_path,
          params: { signed_blob_id: blob.signed_id, title: "EP1", folder_name: "Existing Show" },
          headers: auth_headers
      }.not_to change(Folder, :count)

      expect(Video.last.folder).to eq(folder)
    end

    it "enqueues VideoConversionJob" do
      expect {
        post api_import_videos_path,
          params: { signed_blob_id: blob.signed_id, title: "Convert Me" },
          headers: auth_headers
      }.to have_enqueued_job(VideoConversionJob)
    end

    it "returns unprocessable_entity for invalid signed blob ID" do
      post api_import_videos_path,
        params: { signed_blob_id: "invalid", title: "Bad" },
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid signed blob ID")
    end

    it "returns unauthorized without valid credentials" do
      post api_import_videos_path,
        params: { signed_blob_id: blob.signed_id },
        headers: { "Authorization" => "Bearer invalid" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized without any credentials" do
      post api_import_videos_path, params: { signed_blob_id: blob.signed_id }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
