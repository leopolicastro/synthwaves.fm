require "rails_helper"

RSpec.describe "Subsonic System API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test"} }

  describe "GET /api/rest/ping.view" do
    it "returns ok for valid credentials" do
      get "/api/rest/ping.view", params: auth_params.merge(f: "json")
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end

    it "returns failed for invalid credentials" do
      get "/api/rest/ping.view", params: {u: user.email_address, p: "wrong", v: "1.16.1", c: "test", f: "json"}
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end

    it "returns failed for nonexistent user" do
      get "/api/rest/ping.view", params: {u: "nobody@example.com", p: "x", v: "1.16.1", c: "test", f: "json"}
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end

    it "returns failed when no auth params provided" do
      get "/api/rest/ping.view", params: {u: user.email_address, v: "1.16.1", c: "test", f: "json"}
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
    end

    it "supports hex-encoded password" do
      hex = "enc:" + "testpass".bytes.map { |b| format("%02x", b) }.join
      get "/api/rest/ping.view", params: {u: user.email_address, p: hex, v: "1.16.1", c: "test", f: "json"}
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end

    it "supports token-based auth" do
      salt = "abc123"
      token = Digest::MD5.hexdigest("testpass#{salt}")
      get "/api/rest/ping.view", params: {u: user.email_address, t: token, s: salt, v: "1.16.1", c: "test", f: "json"}
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")
    end
  end

  describe "GET /api/rest/getLicense.view" do
    it "returns a valid license" do
      get "/api/rest/getLicense.view", params: auth_params.merge(f: "json")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["license"]["valid"]).to be true
    end
  end

  describe "XML response format" do
    it "returns valid XML for ping when no format param is specified" do
      get "/api/rest/ping.view", params: auth_params
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("xml")
      doc = Nokogiri::XML(response.body)
      node = doc.at("subsonic-response")
      expect(node["status"]).to eq("ok")
      expect(node["version"]).to eq("1.16.1")
    end

    it "returns valid XML for error responses" do
      get "/api/rest/ping.view", params: {u: user.email_address, p: "wrong", v: "1.16.1", c: "test"}
      expect(response.content_type).to include("xml")
      doc = Nokogiri::XML(response.body)
      node = doc.at("subsonic-response")
      expect(node["status"]).to eq("failed")
      error = doc.at("error")
      expect(error["code"]).to be_present
      expect(error["message"]).to be_present
    end
  end
end
