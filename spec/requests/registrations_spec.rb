require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /registration/new" do
    it "renders the registration form" do
      get new_registration_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects authenticated users" do
      user = create(:user)
      login_user(user)

      get new_registration_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /registration" do
    it "creates a user and starts a session" do
      expect {
        post registration_path, params: {
          user: {
            email_address: "newuser@example.com",
            password: "securepassword",
            password_confirmation: "securepassword"
          }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_url)
    end

    it "rejects duplicate email addresses" do
      create(:user, email_address: "taken@example.com")

      expect {
        post registration_path, params: {
          user: {
            email_address: "taken@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects missing password" do
      expect {
        post registration_path, params: {
          user: {
            email_address: "user@example.com",
            password: "",
            password_confirmation: ""
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects mismatched password confirmation" do
      expect {
        post registration_path, params: {
          user: {
            email_address: "user@example.com",
            password: "password123",
            password_confirmation: "different"
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "redirects authenticated users" do
      user = create(:user)
      login_user(user)

      post registration_path, params: {
        user: {
          email_address: "another@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      expect(response).to redirect_to(root_path)
    end
  end
end
