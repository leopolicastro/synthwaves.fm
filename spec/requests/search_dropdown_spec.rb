require "rails_helper"

RSpec.describe "Search Dropdown", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /search/dropdown" do
    it "returns success without query" do
      get search_dropdown_path
      expect(response).to have_http_status(:ok)
    end

    it "renders without layout" do
      get search_dropdown_path, params: {q: "test"}
      expect(response.body).not_to include("<html")
    end

    it "returns matching artists" do
      create(:artist, name: "The Beatles", user: user)
      get search_dropdown_path, params: {q: "Beatles"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The Beatles")
      expect(response.body).to include("Artists")
    end

    it "returns matching albums" do
      artist = create(:artist, name: "Pink Floyd", user: user)
      create(:album, title: "The Wall", artist: artist)
      get search_dropdown_path, params: {q: "Wall"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The Wall")
      expect(response.body).to include("Albums")
    end

    it "returns matching tracks" do
      artist = create(:artist, name: "Queen", user: user)
      album = create(:album, title: "A Night at the Opera", artist: artist)
      create(:track, title: "Bohemian Rhapsody", artist: artist, album: album)
      get search_dropdown_path, params: {q: "Bohemian"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bohemian Rhapsody")
      expect(response.body).to include("Tracks")
    end

    it "shows no results message when nothing matches" do
      get search_dropdown_path, params: {q: "xyznonexistent"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No results found")
    end

    it "includes a link to the full search page" do
      create(:artist, name: "Radiohead", user: user)
      get search_dropdown_path, params: {q: "Radiohead"}
      expect(response.body).to include("See all results")
      expect(response.body).to include(search_path(q: "Radiohead"))
    end

    it "wraps results in a turbo frame" do
      get search_dropdown_path, params: {q: "test"}
      expect(response.body).to include('id="navbar-search-results"')
    end
  end
end
