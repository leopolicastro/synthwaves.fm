require "rails_helper"

RSpec.describe ItunesSearch do
  describe ".call" do
    let(:itunes_response) do
      {
        "resultCount" => 1,
        "results" => [
          {
            "artistName" => "Daft Punk",
            "collectionName" => "Random Access Memories",
            "trackName" => "Get Lucky",
            "trackNumber" => 8,
            "discNumber" => 1,
            "primaryGenreName" => "Electronic",
            "releaseDate" => "2013-05-21T07:00:00Z",
            "artworkUrl100" => "https://example.com/art100x100bb.jpg"
          }
        ]
      }
    end

    it "returns enriched metadata from iTunes" do
      stub_request(:get, /itunes\.apple\.com\/search/)
        .to_return(status: 200, body: itunes_response.to_json, headers: {"Content-Type" => "application/json"})

      result = described_class.call(artist: "Daft Punk", title: "Get Lucky")

      expect(result[:artist]).to eq("Daft Punk")
      expect(result[:album]).to eq("Random Access Memories")
      expect(result[:title]).to eq("Get Lucky")
      expect(result[:track_number]).to eq(8)
      expect(result[:genre]).to eq("Electronic")
      expect(result[:year]).to eq(2013)
      expect(result[:artwork_url]).to eq("https://example.com/art600x600bb.jpg")
    end

    it "returns nil when no results found" do
      stub_request(:get, /itunes\.apple\.com\/search/)
        .to_return(status: 200, body: {"resultCount" => 0, "results" => []}.to_json, headers: {"Content-Type" => "application/json"})

      result = described_class.call(artist: "Unknown", title: "Nothing")
      expect(result).to be_nil
    end

    it "returns nil when API errors" do
      stub_request(:get, /itunes\.apple\.com\/search/)
        .to_return(status: 500, body: "Internal Server Error")

      result = described_class.call(artist: "Daft Punk", title: "Get Lucky")
      expect(result).to be_nil
    end

    it "returns nil when both artist and title are blank" do
      result = described_class.call(artist: nil, title: nil)
      expect(result).to be_nil
    end

    it "upgrades artwork URL to 600x600" do
      stub_request(:get, /itunes\.apple\.com\/search/)
        .to_return(status: 200, body: itunes_response.to_json, headers: {"Content-Type" => "application/json"})

      result = described_class.call(artist: "Daft Punk", title: "Get Lucky")
      expect(result[:artwork_url]).to include("600x600")
      expect(result[:artwork_url]).not_to include("100x100")
    end
  end
end
