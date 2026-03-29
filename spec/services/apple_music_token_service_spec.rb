require "rails_helper"

RSpec.describe AppleMusicTokenService do
  describe ".token" do
    context "when credentials are configured" do
      before do
        # Generate a test EC key
        ec_key = OpenSSL::PKey::EC.generate("prime256v1")

        allow(Rails.application.credentials).to receive(:apple_music).and_return({
          team_id: "TEAM123456",
          key_id: "KEY1234567",
          private_key: ec_key.to_pem
        })

        Rails.cache.delete(described_class::CACHE_KEY)
      end

      it "returns a valid JWT token" do
        token = described_class.token
        expect(token).to be_a(String)
        expect(token.split(".").length).to eq(3)
      end

      it "caches the token" do
        allow(Rails.cache).to receive(:fetch).and_call_original
        described_class.token
        expect(Rails.cache).to have_received(:fetch).with(described_class::CACHE_KEY, expires_in: anything)
      end

      it "includes correct JWT headers" do
        token = described_class.token
        header = JWT.decode(token, nil, false).last
        expect(header["alg"]).to eq("ES256")
        expect(header["kid"]).to eq("KEY1234567")
      end
    end

    context "when credentials are not configured" do
      before do
        allow(Rails.application.credentials).to receive(:apple_music).and_return(nil)
        Rails.cache.delete(described_class::CACHE_KEY)
      end

      it "raises an error" do
        expect { described_class.token }.to raise_error(AppleMusicTokenService::Error, /not configured/)
      end
    end
  end

  describe ".configured?" do
    it "returns true when all credentials are present" do
      allow(Rails.application.credentials).to receive(:apple_music).and_return({
        team_id: "TEAM123456",
        key_id: "KEY1234567",
        private_key: "-----BEGIN PRIVATE KEY-----\nfake\n-----END PRIVATE KEY-----"
      })

      expect(described_class.configured?).to be true
    end

    it "returns false when credentials are missing" do
      allow(Rails.application.credentials).to receive(:apple_music).and_return(nil)
      expect(described_class.configured?).to be false
    end
  end
end
