require "rails_helper"

RSpec.describe "Subsonic Media API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/stream.view" do
    it "redirects when audio file is attached" do
      track = create(:track, user: user)
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get "/api/rest/stream.view", params: auth_params.merge(id: track.id)
      expect(response).to have_http_status(:redirect)
    end

    it "redirects to an https URL when audio file is attached" do
      track = create(:track, user: user)
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get "/api/rest/stream.view", params: auth_params.merge(id: track.id), headers: {"HTTPS" => "on"}
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://")
    end

    it "returns error when no audio file attached" do
      track = create(:track, :youtube, user: user)
      get "/api/rest/stream.view", params: auth_params.merge(id: track.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error for nonexistent track" do
      get "/api/rest/stream.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/download.view" do
    it "redirects when audio file is attached" do
      track = create(:track, user: user)
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get "/api/rest/download.view", params: auth_params.merge(id: track.id)
      expect(response).to have_http_status(:redirect)
    end

    it "redirects to an https URL when audio file is attached" do
      track = create(:track, user: user)
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get "/api/rest/download.view", params: auth_params.merge(id: track.id), headers: {"HTTPS" => "on"}
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://")
    end

    it "returns error when no audio file attached" do
      track = create(:track, :youtube, user: user)
      get "/api/rest/download.view", params: auth_params.merge(id: track.id)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error for nonexistent track" do
      get "/api/rest/download.view", params: auth_params.merge(id: 99999)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /api/rest/getCoverArt.view" do
    it "redirects when cover image is attached" do
      album = create(:album, user: user)
      album.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )

      get "/api/rest/getCoverArt.view", params: auth_params.merge(id: album.id)
      expect(response).to have_http_status(:redirect)
    end

    it "redirects to an https URL when cover image is attached" do
      album = create(:album, user: user)
      album.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )

      get "/api/rest/getCoverArt.view", params: auth_params.merge(id: album.id), headers: {"HTTPS" => "on"}
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("https://")
    end

    it "returns 404 when no cover image" do
      album = create(:album, user: user)
      get "/api/rest/getCoverArt.view", params: auth_params.merge(id: album.id)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for nonexistent album" do
      get "/api/rest/getCoverArt.view", params: auth_params.merge(id: 99999)
      expect(response).to have_http_status(:not_found)
    end
  end
end
