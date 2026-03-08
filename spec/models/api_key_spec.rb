require "rails_helper"

RSpec.describe APIKey, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    subject { build(:api_key, client_id: "bc_test_unique_id") }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:client_id) }

    it "validates presence of client_id at the database level" do
      # The before_validation callback auto-generates client_id on create,
      # so shoulda's validate_presence_of can't test this directly.
      # Verify the validation exists and would reject a blank client_id
      # when the callback is bypassed (e.g., on update).
      api_key = create(:api_key)
      api_key.client_id = nil
      expect(api_key).not_to be_valid
      expect(api_key.errors[:client_id]).to include("can't be blank")
    end
  end

  describe "callbacks" do
    describe "#generate_client_id" do
      it "generates a client_id on create if not provided" do
        api_key = build(:api_key, client_id: nil)
        api_key.valid?
        expect(api_key.client_id).to start_with("bc_")
        expect(api_key.client_id.length).to eq(35)
      end

      it "does not override provided client_id" do
        api_key = build(:api_key, client_id: "custom_id")
        api_key.valid?
        expect(api_key.client_id).to eq("custom_id")
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      let(:user) { create(:user) }

      it "returns keys without expiration" do
        active_key = create(:api_key, user: user, expires_at: nil)
        expect(described_class.active).to include(active_key)
      end

      it "returns keys with future expiration" do
        future_key = create(:api_key, user: user, expires_at: 1.day.from_now)
        expect(described_class.active).to include(future_key)
      end

      it "excludes expired keys" do
        expired_key = create(:api_key, user: user, expires_at: 1.day.ago)
        expect(described_class.active).not_to include(expired_key)
      end
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      api_key = build(:api_key, expires_at: nil)
      expect(api_key.expired?).to be false
    end

    it "returns false when expires_at is in the future" do
      api_key = build(:api_key, expires_at: 1.day.from_now)
      expect(api_key.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      api_key = build(:api_key, expires_at: 1.day.ago)
      expect(api_key.expired?).to be true
    end
  end

  describe "#touch_last_used!" do
    it "updates last_used_at and last_used_ip" do
      api_key = create(:api_key)
      ip = "192.168.1.1"

      freeze_time do
        api_key.touch_last_used!(ip)

        expect(api_key.last_used_at).to eq(Time.current)
        expect(api_key.last_used_ip).to eq(ip)
      end
    end
  end

  describe "secret key authentication" do
    it "authenticates with correct secret key" do
      api_key = build(:api_key)
      api_key.secret_key = "test_secret_key"
      api_key.save!

      expect(api_key.authenticate_secret_key("test_secret_key")).to eq(api_key)
    end

    it "fails authentication with incorrect secret key" do
      api_key = build(:api_key)
      api_key.secret_key = "test_secret_key"
      api_key.save!

      expect(api_key.authenticate_secret_key("wrong_key")).to be false
    end
  end
end
