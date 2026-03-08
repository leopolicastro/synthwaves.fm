require "rails_helper"

RSpec.describe "PlayHistories", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /play_histories" do
    it "returns success" do
      get play_histories_path
      expect(response).to have_http_status(:ok)
    end

    it "groups tracks under album headers" do
      album = create(:album)
      track1 = create(:track, album: album, artist: album.artist)
      track2 = create(:track, album: album, artist: album.artist)
      create(:play_history, user: user, track: track1, played_at: 2.hours.ago)
      create(:play_history, user: user, track: track2, played_at: 1.hour.ago)

      get play_histories_path
      expect(response.body).to include(album.title)
      expect(response.body).to include(track1.title)
      expect(response.body).to include(track2.title)
    end

    it "shows tracks from different albums under separate headers" do
      album1 = create(:album)
      album2 = create(:album)
      track1 = create(:track, album: album1, artist: album1.artist)
      track2 = create(:track, album: album2, artist: album2.artist)
      create(:play_history, user: user, track: track1, played_at: 2.hours.ago)
      create(:play_history, user: user, track: track2, played_at: 1.hour.ago)

      get play_histories_path
      expect(response.body).to include(album1.title)
      expect(response.body).to include(album2.title)
    end
  end

  describe "POST /play_histories" do
    let(:track) { create(:track) }

    it "records a play" do
      expect {
        post play_histories_path, params: {track_id: track.id}, as: :json
      }.to change(PlayHistory, :count).by(1)
    end

    it "returns not found for nonexistent track" do
      post play_histories_path, params: {track_id: 99999}, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
