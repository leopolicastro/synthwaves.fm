require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /registration/new" do
    context "when open_registration is enabled" do
      before { Flipper.enable(:open_registration) }

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

    context "when open_registration is disabled" do
      before { Flipper.disable(:open_registration) }

      it "redirects to root with an alert" do
        get new_registration_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("This feature is not available.")
      end
    end
  end

  describe "POST /registration" do
    context "when open_registration is enabled" do
      before { Flipper.enable(:open_registration) }

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

    context "when open_registration is disabled" do
      before { Flipper.disable(:open_registration) }

      it "redirects to root and does not create a user" do
        expect {
          post registration_path, params: {
            user: {
              email_address: "newuser@example.com",
              password: "securepassword",
              password_confirmation: "securepassword"
            }
          }
        }.not_to change(User, :count)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("This feature is not available.")
      end
    end
  end

  describe "DELETE /registration" do
    it "deletes the user account and redirects to root" do
      user = create(:user)
      login_user(user)

      expect {
        delete registration_path
      }.to change(User, :count).by(-1)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Your account has been deleted.")
    end

    it "destroys all associated data" do
      user = create(:user)
      login_user(user)

      artist = create(:artist, user: user)
      album = create(:album, artist: artist, user: user)
      track = create(:track, album: album, artist: artist, user: user)
      create(:playlist, user: user)
      create(:favorite, user: user)
      create(:play_history, user: user, track: track)
      create(:external_stream, user: user)
      create(:video, user: user)
      create(:folder, user: user)
      create(:api_key, user: user)

      expect {
        delete registration_path
      }.to change(User, :count).by(-1)
        .and change(Artist, :count).by(-1)
        .and change(Album, :count).by(-1)
        .and change(Track, :count).by(-1)
        .and change(Playlist, :count).by(-1)
        .and change(Favorite, :count).by(-1)
        .and change(PlayHistory, :count).by(-1)
        .and change(ExternalStream, :count).by(-1)
        .and change(Video, :count).by(-1)
        .and change(Folder, :count).by(-1)
        .and change(APIKey, :count).by(-1)
    end

    it "clears the session" do
      user = create(:user)
      login_user(user)

      delete registration_path
      follow_redirect!

      get profile_path
      expect(response).to redirect_to(new_session_path)
    end

    it "requires authentication" do
      delete registration_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
