require "rails_helper"

RSpec.describe "Static::Landing", type: :request do
  describe "GET /" do
    context "when not authenticated" do
      before { get root_path }

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "displays all nine feature cards" do
        expect(response.body).to include("Music Library")
        expect(response.body).to include("Playlists")
        expect(response.body).to include("Stream Anywhere")
        expect(response.body).to include("Live TV")
        expect(response.body).to include("TV Guide & DVR")
        expect(response.body).to include("Podcasts")
        expect(response.body).to include("Internet Radio")
        expect(response.body).to include("Themes")
        expect(response.body).not_to include("AI Assistant")
      end

      it "uses media-focused copy instead of music-only" do
        expect(response.body).to include("Self-hosted media streaming")
        expect(response.body).to include("Your Media, Your Server")
        expect(response.body).to include("A complete media platform")
        expect(response.body).to include("add your media")
      end
    end

    context "when authenticated" do
      let(:user) { User.create!(email_address: "test@example.com", password: "password123") }

      before do
        post session_path, params: {email_address: user.email_address, password: "password123"}
      end

      it "redirects to library" do
        get root_path
        expect(response).to redirect_to(library_path)
      end
    end
  end
end
