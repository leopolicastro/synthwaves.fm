require "rails_helper"

RSpec.describe SubsonicUrlBuilder do
  let(:user) { create(:user, subsonic_password: "testpass123") }
  let(:artist) { create(:artist) }
  let(:album) { create(:album, artist: artist) }
  let(:track) { create(:track, artist: artist, album: album) }
  let(:builder) { described_class.new(user, base_url: "https://example.com") }

  describe "#stream_url" do
    it "returns a URL with the correct path" do
      url = builder.stream_url(track)
      uri = URI.parse(url)
      expect(uri.path).to eq("/rest/stream")
    end

    it "includes the track id" do
      url = builder.stream_url(track)
      params = Rack::Utils.parse_query(URI.parse(url).query)
      expect(params["id"]).to eq(track.id.to_s)
    end

    it "includes auth params with valid MD5 token" do
      url = builder.stream_url(track)
      params = Rack::Utils.parse_query(URI.parse(url).query)

      expect(params["u"]).to eq(user.email_address)
      expect(params["s"]).to be_present
      expect(params["t"]).to eq(Digest::MD5.hexdigest("#{user.subsonic_password}#{params["s"]}"))
    end

    it "includes API version, client, and format" do
      url = builder.stream_url(track)
      params = Rack::Utils.parse_query(URI.parse(url).query)

      expect(params["v"]).to eq(SubsonicResponseFormatting::SUBSONIC_API_VERSION)
      expect(params["c"]).to eq("synthwaves-ios")
      expect(params["f"]).to eq("json")
    end

    it "generates a unique salt per call" do
      url1 = builder.stream_url(track)
      url2 = builder.stream_url(track)
      salt1 = Rack::Utils.parse_query(URI.parse(url1).query)["s"]
      salt2 = Rack::Utils.parse_query(URI.parse(url2).query)["s"]
      expect(salt1).not_to eq(salt2)
    end

    it "uses the provided base_url" do
      url = builder.stream_url(track)
      expect(url).to start_with("https://example.com/rest/stream")
    end
  end

  describe "#cover_art_url" do
    it "returns a URL with the correct path" do
      url = builder.cover_art_url(album)
      uri = URI.parse(url)
      expect(uri.path).to eq("/rest/getCoverArt")
    end

    it "includes album id and default size" do
      url = builder.cover_art_url(album)
      params = Rack::Utils.parse_query(URI.parse(url).query)
      expect(params["id"]).to eq(album.id.to_s)
      expect(params["size"]).to eq("300")
    end

    it "accepts a custom size" do
      url = builder.cover_art_url(album, size: 600)
      params = Rack::Utils.parse_query(URI.parse(url).query)
      expect(params["size"]).to eq("600")
    end

    it "includes valid auth params" do
      url = builder.cover_art_url(album)
      params = Rack::Utils.parse_query(URI.parse(url).query)

      expect(params["u"]).to eq(user.email_address)
      expect(params["t"]).to eq(Digest::MD5.hexdigest("#{user.subsonic_password}#{params["s"]}"))
    end
  end
end
