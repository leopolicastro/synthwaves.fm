require "rails_helper"

RSpec.describe "Passwords", type: :request do
  describe "GET /passwords/new" do
    it "renders the password reset form" do
      get new_password_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /passwords" do
    it "sends reset email for existing user" do
      user = create(:user, email_address: "reset@example.com")

      expect {
        post passwords_path, params: {email_address: "reset@example.com"}
      }.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "redirects without error for non-existent email" do
      post passwords_path, params: {email_address: "nobody@example.com"}

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("Password reset instructions sent")
    end
  end

  describe "GET /passwords/:token/edit" do
    it "renders the reset form with a valid token" do
      user = create(:user)
      token = user.password_reset_token

      get edit_password_path(token)
      expect(response).to have_http_status(:ok)
    end

    it "redirects with invalid token" do
      get edit_password_path("invalid-token")
      expect(response).to redirect_to(new_password_path)
    end
  end

  describe "PATCH /passwords/:token" do
    it "resets the password with valid token" do
      user = create(:user, password: "oldpassword")
      token = user.password_reset_token

      patch password_path(token), params: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("newpassword123")).to be_truthy
    end

    it "destroys all existing sessions on reset" do
      user = create(:user)
      user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
      token = user.password_reset_token

      expect {
        patch password_path(token), params: {
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }
      }.to change { user.sessions.count }.to(0)
    end

    it "rejects mismatched passwords" do
      user = create(:user)
      token = user.password_reset_token

      patch password_path(token), params: {
        password: "newpassword123",
        password_confirmation: "different"
      }

      expect(response).to redirect_to(edit_password_path(token))
    end

    it "rejects expired/invalid token" do
      patch password_path("invalid-token"), params: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }

      expect(response).to redirect_to(new_password_path)
    end
  end
end
