require "rails_helper"

RSpec.describe StationUrlImportService do
  describe "#call" do
    context "when URL is a direct audio stream" do
      it "creates a station from the stream URL" do
        stub_request(:get, "https://stream.example.com/radio.mp3")
          .to_return(
            headers: {"Content-Type" => "audio/mpeg"},
            body: "fake audio data"
          )

        result = described_class.new("https://stream.example.com/radio.mp3").call

        expect(result[:station]).to be_persisted
        expect(result[:station].stream_url).to eq("https://stream.example.com/radio.mp3")
      end
    end

    context "when page contains an audio source tag" do
      it "extracts the stream URL" do
        html = <<~HTML
          <html>
            <head><title>Cool Radio Station</title></head>
            <body>
              <audio><source src="https://stream.example.com/live.mp3"></audio>
            </body>
          </html>
        HTML

        stub_request(:get, "https://coolradio.com/")
          .to_return(headers: {"Content-Type" => "text/html"}, body: html)

        result = described_class.new("https://coolradio.com/").call

        expect(result[:station]).to be_persisted
        expect(result[:station].name).to eq("Cool Radio Station")
        expect(result[:station].stream_url).to eq("https://stream.example.com/live.mp3")
      end
    end

    context "when page contains a stream link" do
      it "extracts stream URL from an anchor tag" do
        html = <<~HTML
          <html>
            <head><title>Rock FM</title></head>
            <body>
              <a href="https://cdn.example.com/rock.aac?token=abc">Listen</a>
            </body>
          </html>
        HTML

        stub_request(:get, "https://rockfm.com/")
          .to_return(headers: {"Content-Type" => "text/html"}, body: html)

        result = described_class.new("https://rockfm.com/").call

        expect(result[:station]).to be_persisted
        expect(result[:station].stream_url).to eq("https://cdn.example.com/rock.aac?token=abc")
      end
    end

    context "when page embeds stream URL in JSON (iHeart-style)" do
      it "extracts secure_shoutcast_stream" do
        html = <<~HTML
          <html>
            <head><title>POWER96 | iHeart</title></head>
            <body>
              <script>window.__data = {"secure_shoutcast_stream":"https://live.amperwave.net/direct/audacy-wpowfmaac-imc","other":"data"}</script>
            </body>
          </html>
        HTML

        stub_request(:get, "https://www.iheart.com/live/power96-10921/")
          .to_return(headers: {"Content-Type" => "text/html"}, body: html)

        result = described_class.new("https://www.iheart.com/live/power96-10921/").call

        expect(result[:station]).to be_persisted
        expect(result[:station].name).to eq("POWER96 | iHeart")
        expect(result[:station].stream_url).to eq("https://live.amperwave.net/direct/audacy-wpowfmaac-imc")
        expect(result[:station].homepage_url).to eq("https://www.iheart.com/live/power96-10921/")
      end
    end

    context "when no stream URL found but Radio Browser has it" do
      it "falls back to Radio Browser API" do
        html = <<~HTML
          <html>
            <head><title>Big 105.9</title></head>
            <body><p>Welcome</p></body>
          </html>
        HTML

        stub_request(:get, "https://big1059.iheart.com/")
          .to_return(headers: {"Content-Type" => "text/html"}, body: html)

        stub_request(:get, "https://de1.api.radio-browser.info/json/stations/byname/Big%20105.9")
          .with(query: hash_including("limit" => "5"))
          .to_return(body: [
            {
              "stationuuid" => "big-1059-uuid",
              "name" => "Big 105.9",
              "url_resolved" => "https://stream.iheart.com/big1059.mp3",
              "url" => "https://stream.iheart.com/big1059.mp3",
              "homepage" => "https://big1059.iheart.com",
              "favicon" => "https://big1059.iheart.com/logo.png",
              "country" => "United States",
              "countrycode" => "US",
              "language" => "english",
              "tags" => "classic rock",
              "codec" => "MP3",
              "bitrate" => 128,
              "votes" => 50
            }
          ].to_json, headers: {"Content-Type" => "application/json"})

        result = described_class.new("https://big1059.iheart.com/").call

        expect(result[:station]).to be_persisted
        expect(result[:station].name).to eq("Big 105.9")
        expect(result[:station].stream_url).to eq("https://stream.iheart.com/big1059.mp3")
      end
    end

    context "when Radio Browser matches on shorter name variant" do
      it "tries the part before the separator" do
        html = <<~HTML
          <html>
            <head><title>BIG 105.9 - Rock's Greatest Hits</title></head>
            <body><p>Welcome</p></body>
          </html>
        HTML

        stub_request(:get, "https://big1059.iheart.com/")
          .to_return(headers: {"Content-Type" => "text/html"}, body: html)

        # Full title returns nothing
        stub_request(:get, /stations\/byname\/BIG%20105.9%20-%20Rock/)
          .with(query: hash_including("limit" => "5"))
          .to_return(body: "[]", headers: {"Content-Type" => "application/json"})

        # Shorter name finds the station
        stub_request(:get, /stations\/byname\/BIG%20105.9/)
          .with(query: hash_including("limit" => "5"))
          .to_return(body: [
            {
              "stationuuid" => "big-1059-uuid",
              "name" => "BIG 105.9",
              "url_resolved" => "https://stream.iheart.com/big1059.mp3",
              "url" => "https://stream.iheart.com/big1059.mp3",
              "homepage" => "",
              "favicon" => "",
              "country" => "United States",
              "countrycode" => "US",
              "language" => "english",
              "tags" => "classic rock",
              "codec" => "MP3",
              "bitrate" => 128,
              "votes" => 50
            }
          ].to_json, headers: {"Content-Type" => "application/json"})

        result = described_class.new("https://big1059.iheart.com/").call

        expect(result[:station]).to be_persisted
        expect(result[:station].name).to eq("BIG 105.9")
        expect(result[:station].stream_url).to eq("https://stream.iheart.com/big1059.mp3")
      end
    end

    context "when no stream URL found anywhere" do
      it "returns an error" do
        html = "<html><head><title></title></head><body></body></html>"

        stub_request(:get, "https://noradio.example.com/")
          .to_return(headers: {"Content-Type" => "text/html"}, body: html)

        stub_request(:get, /de1\.api\.radio-browser\.info/)
          .to_return(body: "[]", headers: {"Content-Type" => "application/json"})

        result = described_class.new("https://noradio.example.com/").call

        expect(result[:error]).to include("Could not find a stream URL")
      end
    end
  end
end
