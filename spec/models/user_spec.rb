require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:sessions).dependent(:destroy) }
    it { should have_many(:api_keys).dependent(:destroy) }
    it { should have_many(:playlists).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
    it { should have_many(:play_histories).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email_address) }
    it { should validate_uniqueness_of(:email_address).ignoring_case_sensitivity }

    it "rejects invalid email formats" do
      user = build(:user, email_address: "not-an-email")
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to be_present
    end

    it "accepts valid email formats" do
      user = build(:user, email_address: "valid@example.com")
      expect(user).to be_valid
    end
  end

  describe "normalizes :email_address" do
    it "strips leading and trailing whitespace" do
      user = create(:user, email_address: "  padded@example.com  ")
      expect(user.email_address).to eq("padded@example.com")
    end

    it "downcases the email address" do
      user = create(:user, email_address: "UPPER@EXAMPLE.COM")
      expect(user.email_address).to eq("upper@example.com")
    end

    it "strips and downcases simultaneously" do
      user = create(:user, email_address: "  Mixed@Case.COM  ")
      expect(user.email_address).to eq("mixed@case.com")
    end
  end
end
