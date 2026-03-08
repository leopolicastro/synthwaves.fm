require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /profile" do
    it "requires authentication" do
      get profile_path
      expect(response).to redirect_to(new_session_path)
    end

    it "returns success for authenticated users" do
      user = create(:user)
      login_user(user)

      get profile_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /profile/edit" do
    it "requires authentication" do
      get edit_profile_path
      expect(response).to redirect_to(new_session_path)
    end

    it "returns success for authenticated users" do
      user = create(:user)
      login_user(user)

      get edit_profile_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /profile" do
    it "requires authentication" do
      patch profile_path, params: {user: {name: "New Name"}}
      expect(response).to redirect_to(new_session_path)
    end

    context "with valid data" do
      it "updates the user name" do
        user = create(:user, name: "Old Name")
        login_user(user)

        patch profile_path, params: {user: {name: "New Name"}}

        expect(response).to redirect_to(profile_path)
        expect(user.reload.name).to eq("New Name")
      end

      it "updates the user email" do
        user = create(:user, email_address: "old@example.com")
        login_user(user)

        patch profile_path, params: {user: {email_address: "new@example.com"}}

        expect(response).to redirect_to(profile_path)
        expect(user.reload.email_address).to eq("new@example.com")
      end

      it "sets flash notice on success" do
        user = create(:user)
        login_user(user)

        patch profile_path, params: {user: {name: "Updated"}}

        expect(flash[:notice]).to eq("Profile updated successfully.")
      end
    end

    context "with subsonic_password" do
      it "updates the subsonic password" do
        user = create(:user, subsonic_password: "oldpass")
        login_user(user)

        patch profile_path, params: {user: {subsonic_password: "newpass"}}

        expect(response).to redirect_to(profile_path)
        expect(user.reload.subsonic_password).to eq("newpass")
      end
    end

    context "with invalid data" do
      it "re-renders form with blank email" do
        user = create(:user)
        login_user(user)

        patch profile_path, params: {user: {email_address: ""}}

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "re-renders form with invalid email format" do
        user = create(:user)
        login_user(user)

        patch profile_path, params: {user: {email_address: "invalid-email"}}

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "re-renders form with duplicate email" do
        create(:user, email_address: "taken@example.com")
        user = create(:user, email_address: "myemail@example.com")
        login_user(user)

        patch profile_path, params: {user: {email_address: "taken@example.com"}}

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
