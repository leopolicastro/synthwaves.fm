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

    describe "theme" do
      it "defaults to synthwave" do
        user = User.new
        expect(user.theme).to eq("synthwave")
      end

      it "accepts valid themes" do
        Themeable::THEMES.each_key do |theme|
          user = build(:user, theme: theme)
          expect(user).to be_valid
        end
      end

      it "rejects invalid themes" do
        user = build(:user, theme: "vaporwave")
        expect(user).not_to be_valid
        expect(user.errors[:theme]).to be_present
      end
    end
  end

  describe "subsonic_password auto-generation" do
    it "generates a subsonic_password on create when none is set" do
      user = create(:user, subsonic_password: nil)
      expect(user.subsonic_password).to be_present
      expect(user.subsonic_password.length).to eq(32)
    end

    it "preserves an existing subsonic_password on create" do
      user = create(:user, subsonic_password: "my_custom_password")
      expect(user.subsonic_password).to eq("my_custom_password")
    end
  end

  describe "#favorited_ids_for" do
    let(:user) { create(:user) }

    it "returns a set of IDs for the given favorable type" do
      track1 = create(:track)
      track2 = create(:track)
      create(:favorite, user: user, favorable: track1)
      create(:favorite, user: user, favorable: track2)

      result = user.favorited_ids_for("Track")

      expect(result).to be_a(Set)
      expect(result).to contain_exactly(track1.id, track2.id)
    end

    it "does not include IDs of other favorable types" do
      track = create(:track)
      artist = create(:artist)
      create(:favorite, user: user, favorable: track)
      create(:favorite, user: user, favorable: artist)

      expect(user.favorited_ids_for("Track")).to contain_exactly(track.id)
      expect(user.favorited_ids_for("Artist")).to contain_exactly(artist.id)
    end

    it "returns an empty set when user has no favorites of that type" do
      result = user.favorited_ids_for("Track")
      expect(result).to be_empty
      expect(result).to be_a(Set)
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
