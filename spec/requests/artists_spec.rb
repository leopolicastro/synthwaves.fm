require "rails_helper"

RSpec.describe "Artists", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /artists" do
    it "returns success" do
      create(:artist, user: user)
      get artists_path
      expect(response).to have_http_status(:ok)
    end

    it "displays album cover image as artist thumbnail" do
      artist = create(:artist, name: "Cover Artist", user: user)
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
      create(:artist, name: "No Cover Artist", user: user)

      get artists_path

      expect(response.body).to include("No Cover Artist")
      expect(response.body).to include("M10 9a3 3 0 100-6 3 3 0 000 6z")
    end

    it "excludes podcast artists from index" do
      music_artist = create(:artist, name: "Music Band", user: user)
      podcast_artist = create(:artist, :podcast, name: "Podcast Show", user: user)

      get artists_path

      expect(response.body).to include("Music Band")
      expect(response.body).not_to include("Podcast Show")
    end

    it "filters artists by search query" do
      create(:artist, name: "The Beatles", user: user)
      create(:artist, name: "Led Zeppelin", user: user)

      get artists_path, params: { q: "Beatles" }

      expect(response.body).to include("The Beatles")
      expect(response.body).not_to include("Led Zeppelin")
    end

    it "shows no artists found message when search has no results" do
      create(:artist, name: "The Beatles", user: user)

      get artists_path, params: { q: "Nonexistent" }

      expect(response.body).to include("No artists found")
      expect(response.body).to include("Nonexistent")
    end

    it "sorts artists by name ascending by default" do
      create(:artist, name: "Zebra", user: user)
      create(:artist, name: "Alpha", user: user)

      get artists_path

      expect(response.body.index("Alpha")).to be < response.body.index("Zebra")
    end

    it "sorts artists by name descending" do
      create(:artist, name: "Zebra", user: user)
      create(:artist, name: "Alpha", user: user)

      get artists_path, params: { sort: "name", direction: "desc" }

      expect(response.body.index("Zebra")).to be < response.body.index("Alpha")
    end

    it "sorts artists by recently added" do
      older = create(:artist, name: "Older Artist", user: user, created_at: 2.days.ago)
      newer = create(:artist, name: "Newer Artist", user: user, created_at: 1.hour.ago)

      get artists_path, params: { sort: "created_at", direction: "desc" }

      expect(response.body.index("Newer Artist")).to be < response.body.index("Older Artist")
    end

    it "paginates results" do
      26.times { |i| create(:artist, name: "Artist #{i.to_s.rjust(2, '0')}", user: user) }

      get artists_path

      expect(response).to have_http_status(:ok)
    end

    it "renders artist links that break out of the turbo frame" do
      create(:artist, name: "Turbo Artist", user: user)

      get artists_path

      expect(response.body).to include('data-turbo-frame="_top"')
    end
  end

  describe "GET /artists/:id" do
    it "returns success" do
      artist = create(:artist, user: user)
      get artist_path(artist)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /artists/:id/edit" do
    let(:admin) { create(:user, admin: true) }

    before { login_user(admin) }

    it "returns success for admin" do
      artist = create(:artist, user: admin)
      get edit_artist_path(artist)
      expect(response).to have_http_status(:ok)
    end

    it "redirects non-admin" do
      login_user(user)
      artist = create(:artist, user: user)
      get edit_artist_path(artist)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /artists/:id" do
    let(:admin) { create(:user, admin: true) }

    before { login_user(admin) }

    it "updates artist name" do
      artist = create(:artist, name: "Old Name", user: admin)
      patch artist_path(artist), params: {artist: {name: "New Name"}}

      expect(artist.reload.name).to eq("New Name")
      expect(response).to redirect_to(artist_path(artist))
    end

    it "updates artist category" do
      artist = create(:artist, category: "music", user: admin)
      patch artist_path(artist), params: {artist: {category: "podcast"}}

      expect(artist.reload.category).to eq("podcast")
    end

    it "renders edit on validation error" do
      create(:artist, name: "Taken", user: admin)
      artist = create(:artist, name: "Other", user: admin)

      patch artist_path(artist), params: {artist: {name: "Taken"}}

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "redirects non-admin" do
      login_user(user)
      artist = create(:artist, name: "Original", user: user)
      patch artist_path(artist), params: {artist: {name: "Hacked"}}
      expect(response).to redirect_to(root_path)
      expect(artist.reload.name).to eq("Original")
    end
  end

  describe "DELETE /artists/:id" do
    let(:admin) { create(:user, admin: true) }

    before { login_user(admin) }

    it "deletes the artist and cascades to albums and tracks" do
      artist = create(:artist, user: admin)
      album = create(:album, artist: artist)
      create(:track, album: album, artist: artist)

      expect {
        delete artist_path(artist)
      }.to change(Artist, :count).by(-1)
        .and change(Album, :count).by(-1)
        .and change(Track, :count).by(-1)

      expect(response).to redirect_to(artists_path)
    end

    it "redirects non-admin" do
      login_user(user)
      artist = create(:artist, user: user)
      delete artist_path(artist)
      expect(response).to redirect_to(root_path)
      expect(Artist.exists?(artist.id)).to be true
    end
  end
end
