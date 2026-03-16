require "rails_helper"

RSpec.describe StreamUrlResolver do
  describe ".call" do
    before do
      # Stub HEAD requests for resolved stream URLs (no redirect by default)
      stub_request(:head, %r{radio\.example\.com}).to_return(status: 200)
    end

    it "parses a PLS file and extracts the stream URL" do
      pls_body = <<~PLS
        [playlist]
        NumberOfEntries=1
        File1=https://radio.example.com/stream
        Title1=Cool Radio
        Length1=-1
      PLS

      stub_request(:get, "https://example.com/station.pls")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/x-scpls"},
          body: pls_body
        )

      result = described_class.call("https://example.com/station.pls")

      expect(result.stream_url).to eq("https://radio.example.com/stream")
      expect(result.name).to eq("Cool Radio")
      expect(result.error).to be_nil
    end

    it "parses a PLS file detected by file extension" do
      pls_body = <<~PLS
        [playlist]
        NumberOfEntries=1
        File1=https://radio.example.com/stream
      PLS

      stub_request(:get, "https://example.com/listen.pls")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "text/plain"},
          body: pls_body
        )

      result = described_class.call("https://example.com/listen.pls")

      expect(result.stream_url).to eq("https://radio.example.com/stream")
      expect(result.error).to be_nil
    end

    it "parses an M3U file and extracts the stream URL" do
      m3u_body = <<~M3U
        #EXTM3U
        #EXTINF:-1,Jazz FM
        https://radio.example.com/jazz
      M3U

      stub_request(:get, "https://example.com/station.m3u")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/x-mpegurl"},
          body: m3u_body
        )

      result = described_class.call("https://example.com/station.m3u")

      expect(result.stream_url).to eq("https://radio.example.com/jazz")
      expect(result.name).to eq("Jazz FM")
      expect(result.error).to be_nil
    end

    it "parses an M3U file without EXTINF header" do
      m3u_body = <<~M3U
        #EXTM3U
        https://radio.example.com/stream
      M3U

      stub_request(:get, "https://example.com/listen.m3u")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/mpegurl"},
          body: m3u_body
        )

      result = described_class.call("https://example.com/listen.m3u")

      expect(result.stream_url).to eq("https://radio.example.com/stream")
      expect(result.name).to be_nil
      expect(result.error).to be_nil
    end

    it "passes through a direct stream URL" do
      stub_request(:get, "https://radio.example.com/stream")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/mpeg"},
          body: "fake audio data"
        )

      result = described_class.call("https://radio.example.com/stream")

      expect(result.stream_url).to eq("https://radio.example.com/stream")
      expect(result.name).to be_nil
      expect(result.error).to be_nil
    end

    it "follows redirects on the resolved stream URL" do
      pls_body = <<~PLS
        [playlist]
        NumberOfEntries=1
        File1=http://radio.example.com/stream
        Title1=Redirect Radio
      PLS

      stub_request(:get, "https://example.com/redirect.pls")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/x-scpls"},
          body: pls_body
        )

      stub_request(:head, "http://radio.example.com/stream")
        .to_return(
          status: 301,
          headers: {"Location" => "https://radio.example.com/stream"}
        )

      result = described_class.call("https://example.com/redirect.pls")

      expect(result.stream_url).to eq("https://radio.example.com/stream")
      expect(result.name).to eq("Redirect Radio")
    end

    it "returns an error when the URL cannot be fetched" do
      stub_request(:get, "https://example.com/broken")
        .to_raise(HTTP::ConnectionError.new("Connection refused"))

      result = described_class.call("https://example.com/broken")

      expect(result.stream_url).to be_nil
      expect(result.error).to include("Could not fetch URL")
    end

    it "returns an error when PLS file has no stream URL" do
      stub_request(:get, "https://example.com/empty.pls")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/x-scpls"},
          body: "[playlist]\nNumberOfEntries=0\n"
        )

      result = described_class.call("https://example.com/empty.pls")

      expect(result.stream_url).to be_nil
      expect(result.error).to include("No stream URL found in PLS file")
    end

    it "returns an error when M3U file has no stream URL" do
      stub_request(:get, "https://example.com/empty.m3u")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "audio/x-mpegurl"},
          body: "#EXTM3U\n"
        )

      result = described_class.call("https://example.com/empty.m3u")

      expect(result.stream_url).to be_nil
      expect(result.error).to include("No stream URL found in M3U file")
    end
  end
end
