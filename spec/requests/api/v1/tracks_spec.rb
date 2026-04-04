require "rails_helper"

RSpec.describe "API::V1::Tracks", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:token) { JWTService.encode({user_id: user.id, api_key_id: api_key.id}) }
  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }
  let(:artist) { create(:artist, user: user) }
  let(:album) { create(:album, artist: artist, user: user) }

  describe "GET /api/v1/tracks" do
    it "returns paginated tracks for the current user" do
      create_list(:track, 3, album: album, artist: artist, user: user)
      create(:track) # other user's track

      get "/api/v1/tracks", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tracks"].length).to eq(3)
      expect(json["pagination"]["total_count"]).to eq(3)
    end

    it "filters by album_id" do
      other_album = create(:album, artist: artist, user: user)
      create(:track, album: album, artist: artist, user: user, title: "Target")
      create(:track, album: other_album, artist: artist, user: user)

      get "/api/v1/tracks", params: {album_id: album.id}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["tracks"].length).to eq(1)
      expect(json["tracks"].first["title"]).to eq("Target")
    end

    it "filters by artist_id" do
      other_artist = create(:artist, user: user)
      other_album = create(:album, artist: other_artist, user: user)
      create(:track, album: album, artist: artist, user: user)
      create(:track, album: other_album, artist: other_artist, user: user)

      get "/api/v1/tracks", params: {artist_id: artist.id}, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json["tracks"].length).to eq(1)
    end

    it "returns unauthorized without a token" do
      get "/api/v1/tracks"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/tracks/:id" do
    it "returns track detail" do
      track = create(:track, album: album, artist: artist, user: user, title: "My Track")

      get "/api/v1/tracks/#{track.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("My Track")
      expect(json["artist"]["name"]).to eq(artist.name)
      expect(json["album"]["title"]).to eq(album.title)
      expect(json["has_audio"]).to be true
    end

    it "returns not found for another user's track" do
      other_track = create(:track)

      get "/api/v1/tracks/#{other_track.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/tracks" do
    context "with explicit params" do
      it "creates a track" do
        expect {
          post "/api/v1/tracks", params: {
            track: {title: "New Track", artist_id: artist.id, album_id: album.id, track_number: 1, duration: 200.0}
          }, headers: auth_headers
        }.to change(Track, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["title"]).to eq("New Track")
        expect(json["artist"]["id"]).to eq(artist.id)
      end

      it "rejects missing title" do
        post "/api/v1/tracks", params: {
          track: {title: "", artist_id: artist.id, album_id: album.id}
        }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with audio file upload" do
      it "creates a track from uploaded audio" do
        file = fixture_file_upload("test.mp3", "audio/mpeg")

        expect {
          post "/api/v1/tracks", params: {audio_file: file}, headers: auth_headers
        }.to change(Track, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["title"]).to be_present
        expect(json["has_audio"]).to be true
      end
    end

    it "returns error without any valid params" do
      post "/api/v1/tracks", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/tracks/:id" do
    it "updates track metadata" do
      track = create(:track, album: album, artist: artist, user: user, title: "Old Title")

      patch "/api/v1/tracks/#{track.id}", params: {track: {title: "New Title"}}, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["title"]).to eq("New Title")
    end

    it "returns not found for another user's track" do
      other_track = create(:track)

      patch "/api/v1/tracks/#{other_track.id}", params: {track: {title: "Hacked"}}, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/tracks/:id" do
    it "deletes the track" do
      track = create(:track, album: album, artist: artist, user: user)

      expect {
        delete "/api/v1/tracks/#{track.id}", headers: auth_headers
      }.to change(Track, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found for another user's track" do
      other_track = create(:track)

      delete "/api/v1/tracks/#{other_track.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/tracks/:id/stream" do
    it "returns the audio file URL" do
      track = create(:track, album: album, artist: artist, user: user)

      get "/api/v1/tracks/#{track.id}/stream", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["url"]).to be_present
      expect(json["content_type"]).to eq("audio/mpeg")
    end

    it "returns not found for a track without audio" do
      track = create(:track, :youtube, album: album, artist: artist, user: user)

      get "/api/v1/tracks/#{track.id}/stream", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
