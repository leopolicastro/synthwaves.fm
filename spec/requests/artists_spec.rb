require "rails_helper"

RSpec.describe "Artists", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /artists" do
    it "returns success" do
      create(:artist)
      get artists_path
      expect(response).to have_http_status(:ok)
    end

    it "displays album cover image as artist thumbnail" do
      artist = create(:artist, name: "Cover Artist")
      album = create(:album, artist: artist)
      album.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )

      get artists_path

      expect(response.body).to include("Cover Artist")
      expect(response.body).not_to include("M10 9a3 3 0 100-6 3 3 0 000 6z")
    end

    it "shows fallback icon when artist has no album cover" do
      create(:artist, name: "No Cover Artist")

      get artists_path

      expect(response.body).to include("No Cover Artist")
      expect(response.body).to include("M10 9a3 3 0 100-6 3 3 0 000 6z")
    end

    it "excludes podcast artists from index" do
      music_artist = create(:artist, name: "Music Band")
      podcast_artist = create(:artist, :podcast, name: "Podcast Show")

      get artists_path

      expect(response.body).to include("Music Band")
      expect(response.body).not_to include("Podcast Show")
    end

    it "filters artists by search query" do
      create(:artist, name: "The Beatles")
      create(:artist, name: "Led Zeppelin")

      get artists_path, params: { q: "Beatles" }

      expect(response.body).to include("The Beatles")
      expect(response.body).not_to include("Led Zeppelin")
    end

    it "shows no artists found message when search has no results" do
      create(:artist, name: "The Beatles")

      get artists_path, params: { q: "Nonexistent" }

      expect(response.body).to include("No artists found")
      expect(response.body).to include("Nonexistent")
    end

    it "sorts artists by name ascending by default" do
      create(:artist, name: "Zebra")
      create(:artist, name: "Alpha")

      get artists_path

      expect(response.body.index("Alpha")).to be < response.body.index("Zebra")
    end

    it "sorts artists by name descending" do
      create(:artist, name: "Zebra")
      create(:artist, name: "Alpha")

      get artists_path, params: { sort: "name", direction: "desc" }

      expect(response.body.index("Zebra")).to be < response.body.index("Alpha")
    end

    it "sorts artists by recently added" do
      older = create(:artist, name: "Older Artist", created_at: 2.days.ago)
      newer = create(:artist, name: "Newer Artist", created_at: 1.hour.ago)

      get artists_path, params: { sort: "created_at", direction: "desc" }

      expect(response.body.index("Newer Artist")).to be < response.body.index("Older Artist")
    end

    it "paginates results" do
      26.times { |i| create(:artist, name: "Artist #{i.to_s.rjust(2, '0')}") }

      get artists_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /artists/:id" do
    it "returns success" do
      artist = create(:artist)
      get artist_path(artist)
      expect(response).to have_http_status(:ok)
    end
  end
end
