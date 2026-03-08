require "rails_helper"

RSpec.describe TrafiClient do
  let(:user) { create(:user) }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:trafi, :base_url).and_return("http://192.168.1.67:8000")
    allow(Rails.application.credentials).to receive(:dig).with(:trafi, :api_key).and_return("test-api-key")
    allow(Rails.application.credentials).to receive(:dig).with(:trafi, :webhook_host).and_return("localhost:3000")
  end

  describe ".download_url" do
    it "creates a SongDownload and posts to Trafi" do
      stub_request(:post, "http://192.168.1.67:8000/download/url")
        .to_return(status: 200, body: {total_tracks: 3}.to_json)

      expect {
        result = described_class.download_url("https://youtube.com/watch?v=abc", user: user)
        expect(result).to be_a(SongDownload)
        expect(result.source_type).to eq("url")
        expect(result.total_tracks).to eq(3)
      }.to change(SongDownload, :count).by(1)
    end

    it "marks download as failed when Trafi returns error" do
      stub_request(:post, "http://192.168.1.67:8000/download/url")
        .to_return(status: 500, body: "Server Error")

      expect {
        described_class.download_url("https://youtube.com/watch?v=abc", user: user)
      }.to raise_error(TrafiClient::Error, /500/)

      expect(SongDownload.last.status).to eq("failed")
    end

    it "includes webhook_url and job_id in the request" do
      stub = stub_request(:post, "http://192.168.1.67:8000/download/url")
        .with { |req|
          body = JSON.parse(req.body)
          body["webhook_url"].present? && body["job_id"].present?
        }
        .to_return(status: 200, body: {}.to_json)

      described_class.download_url("https://youtube.com/watch?v=abc", user: user)
      expect(stub).to have_been_requested
    end
  end

  describe ".download_search" do
    it "creates a SongDownload with search source_type" do
      stub_request(:post, "http://192.168.1.67:8000/download/search")
        .to_return(status: 200, body: {total_tracks: 1}.to_json)

      result = described_class.download_search("Daft Punk Get Lucky", user: user)
      expect(result.source_type).to eq("search")
      expect(result.url).to eq("Daft Punk Get Lucky")
    end
  end
end
