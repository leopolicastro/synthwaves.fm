require "rails_helper"

RSpec.describe "Subsonic /rest/ compatibility routes", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /rest/ping.view" do
    it "returns ok for valid credentials" do
      get "/rest/ping.view", params: auth_params
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end

    it "returns failed for invalid credentials" do
      get "/rest/ping.view", params: {u: user.email_address, p: "wrong", v: "1.16.1", c: "test", f: "json"}
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end
  end

  describe "GET /rest/getArtists.view" do
    it "returns ok" do
      get "/rest/getArtists.view", params: auth_params
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /rest/stream.view" do
    it "redirects when audio file is attached" do
      track = create(:track)
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get "/rest/stream.view", params: auth_params.merge(id: track.id)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /rest/download.view" do
    it "redirects when audio file is attached" do
      track = create(:track)
      track.audio_file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test.mp3")),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      get "/rest/download.view", params: auth_params.merge(id: track.id)
      expect(response).to have_http_status(:redirect)
    end
  end
end
