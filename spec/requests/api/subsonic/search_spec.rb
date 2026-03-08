require "rails_helper"

RSpec.describe "Subsonic Search API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "GET /api/rest/search3.view" do
    it "returns matching results" do
      artist = create(:artist, name: "The Beatles")
      album = create(:album, title: "Abbey Road", artist: artist)
      track = create(:track, title: "Come Together", album: album, artist: artist)

      get "/api/rest/search3.view", params: auth_params.merge(query: "Beatles")
      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["searchResult3"]["artist"]).to be_present
    end
  end
end
