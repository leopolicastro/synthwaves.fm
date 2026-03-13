require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /search" do
    it "returns success without query" do
      get search_path
      expect(response).to have_http_status(:ok)
    end

    it "returns matching results" do
      create(:artist, name: "The Beatles", user: user)
      get search_path, params: {q: "Beatles"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The Beatles")
    end

    it "filters by genre" do
      artist = create(:artist, name: "DJ Pulse", user: user)
      create(:album, title: "Electric Nights", artist: artist, genre: "Electronic")
      create(:album, title: "Rock Nights", artist: artist, genre: "Rock")

      get search_path, params: {q: "Nights", genre: "Electronic"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Electric Nights")
      expect(response.body).not_to include("Rock Nights")
    end

    it "filters by year range" do
      artist = create(:artist, name: "Time Traveler", user: user)
      create(:album, title: "Old Times", artist: artist, year: 2010)
      create(:album, title: "New Times", artist: artist, year: 2023)

      get search_path, params: {q: "Times", year_from: 2020, year_to: 2025}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New Times")
      expect(response.body).not_to include("Old Times")
    end

    it "filters by favorites only" do
      artist = create(:artist, name: "Fave Band", user: user)
      fav_album = create(:album, title: "Loved It", artist: artist)
      create(:album, title: "Skipped It", artist: artist)
      create(:favorite, user: user, favorable: fav_album)

      get search_path, params: {q: "It", favorites_only: "1"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Loved It")
      expect(response.body).not_to include("Skipped It")
    end

    it "populates genre select options" do
      create(:album, title: "Test", artist: create(:artist, user: user), genre: "Jazz")
      create(:album, title: "Test2", artist: create(:artist, user: user), genre: "Electronic")

      get search_path, params: {q: "Test"}
      expect(response.body).to include("Jazz")
      expect(response.body).to include("Electronic")
    end
  end
end
