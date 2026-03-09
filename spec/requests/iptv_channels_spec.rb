require "rails_helper"

RSpec.describe "IPTVChannels", type: :request do
  let(:user) { create(:user) }

  before do
    login_user(user)
    Flipper.enable(:iptv)
  end

  describe "GET /tv" do
    it "returns success" do
      get iptv_channels_path
      expect(response).to have_http_status(:ok)
    end

    it "displays channels" do
      create(:iptv_channel, name: "CNN International")
      get iptv_channels_path
      expect(response.body).to include("CNN International")
    end

    it "filters by category" do
      news = create(:iptv_category, name: "News", slug: "news")
      music = create(:iptv_category, name: "Music", slug: "music")
      cnn = create(:iptv_channel, name: "CNN", iptv_category: news)
      _mtv = create(:iptv_channel, name: "MTV", iptv_category: music)

      get iptv_channels_path(category: "news")
      expect(response.body).to include("CNN")
      expect(response.body).not_to include("MTV")
    end

    it "filters by search query" do
      create(:iptv_channel, name: "CNN International")
      create(:iptv_channel, name: "BBC World")

      get iptv_channels_path(q: "CNN")
      expect(response.body).to include("CNN International")
      expect(response.body).not_to include("BBC World")
    end

    it "filters by country" do
      create(:iptv_channel, name: "CNN", country: "US")
      create(:iptv_channel, name: "BBC", country: "UK")

      get iptv_channels_path(country: "US")
      expect(response.body).to include("CNN")
      expect(response.body).not_to include("BBC")
    end

    it "excludes inactive channels" do
      create(:iptv_channel, name: "Active Channel", active: true)
      create(:iptv_channel, name: "Dead Channel", active: false)

      get iptv_channels_path
      expect(response.body).to include("Active Channel")
      expect(response.body).not_to include("Dead Channel")
    end

    it "renders the TV Guide grid" do
      create(:iptv_channel, name: "ESPN")
      get iptv_channels_path
      expect(response.body).to include("tv-guide")
      expect(response.body).to include("ESPN")
    end

    it "displays EPG programme data in the guide" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")

      get iptv_channels_path
      expect(response.body).to include("NHL Hockey")
    end

    it "shows no schedule info when EPG data is missing" do
      create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")

      get iptv_channels_path
      expect(response.body).to include("No schedule info")
    end

    it "populates recording statuses for programmes in the guide" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      programme = create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")
      recording = create(:recording, iptv_channel: channel, epg_programme: programme, status: "scheduled",
                          title: programme.title, starts_at: programme.starts_at, ends_at: programme.ends_at)
      create(:user_recording, user: user, recording: recording)

      get iptv_channels_path
      expect(response.body).to include('title="Scheduled"')
    end

    it "shows record button for programmes without recordings" do
      create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")

      get iptv_channels_path
      expect(response.body).to include('title="Record"')
    end

    it "excludes failed and cancelled recordings from status indicators" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      programme = create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")
      recording = create(:recording, :failed, iptv_channel: channel, epg_programme: programme,
                          title: programme.title, starts_at: programme.starts_at, ends_at: programme.ends_at)
      create(:user_recording, user: user, recording: recording)

      get iptv_channels_path
      expect(response.body).not_to include('title="Scheduled"')
      expect(response.body).to include('title="Record"')
    end
  end

  describe "GET /tv/:id" do
    it "returns success" do
      channel = create(:iptv_channel)
      get iptv_channel_path(channel)
      expect(response).to have_http_status(:ok)
    end

    it "displays channel details" do
      channel = create(:iptv_channel, name: "CNN International")
      get iptv_channel_path(channel)
      expect(response.body).to include("CNN International")
    end

    it "displays now playing info" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey", subtitle: "Red Wings @ Devils")

      get iptv_channel_path(channel)
      expect(response.body).to include("Now Playing")
      expect(response.body).to include("NHL Hockey")
      expect(response.body).to include("Red Wings @ Devils")
    end

    it "displays up next info" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      create(:epg_programme, :upcoming, channel_id: "espn.us", title: "SportsCenter")

      get iptv_channel_path(channel)
      expect(response.body).to include("Up Next")
      expect(response.body).to include("SportsCenter")
    end

    it "renders gracefully without EPG data" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      get iptv_channel_path(channel)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Now Playing")
      expect(response.body).not_to include("Up Next")
    end

    it "shows scheduled indicator for a recorded now-playing programme" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      programme = create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")
      recording = create(:recording, iptv_channel: channel, epg_programme: programme, status: "scheduled",
                          title: programme.title, starts_at: programme.starts_at, ends_at: programme.ends_at)
      create(:user_recording, user: user, recording: recording)

      get iptv_channel_path(channel)
      expect(response.body).to include('title="Scheduled"')
    end

    it "shows recording indicator for an actively recording programme" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      programme = create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")
      recording = create(:recording, :recording_now, iptv_channel: channel, epg_programme: programme,
                          title: programme.title, starts_at: programme.starts_at, ends_at: programme.ends_at)
      create(:user_recording, user: user, recording: recording)

      get iptv_channel_path(channel)
      expect(response.body).to include('title="Recording..."')
    end

    it "shows recorded indicator for a ready recording" do
      channel = create(:iptv_channel, name: "ESPN", tvg_id: "espn.us")
      programme = create(:epg_programme, :current, channel_id: "espn.us", title: "NHL Hockey")
      recording = create(:recording, :ready, iptv_channel: channel, epg_programme: programme,
                          title: programme.title, starts_at: programme.starts_at, ends_at: programme.ends_at)
      create(:user_recording, user: user, recording: recording)

      get iptv_channel_path(channel)
      expect(response.body).to include('title="Recorded"')
    end
  end

  describe "GET /tv/new" do
    it "returns success" do
      get new_iptv_channel_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tv" do
    it "creates a channel" do
      expect {
        post iptv_channels_path, params: { iptv_channel: {
          name: "Test Channel",
          stream_url: "https://stream.example.com/live.m3u8"
        } }
      }.to change(IPTVChannel, :count).by(1)

      expect(response).to redirect_to(iptv_channel_path(IPTVChannel.last))
    end

    it "rejects invalid channel" do
      post iptv_channels_path, params: { iptv_channel: { name: "", stream_url: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /tv/:id/edit" do
    it "returns success" do
      channel = create(:iptv_channel)
      get edit_iptv_channel_path(channel)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /tv/:id" do
    it "updates the channel" do
      channel = create(:iptv_channel, name: "Old Name")
      patch iptv_channel_path(channel), params: { iptv_channel: { name: "New Name" } }

      expect(channel.reload.name).to eq("New Name")
      expect(response).to redirect_to(iptv_channel_path(channel))
    end
  end

  describe "DELETE /tv/:id" do
    it "deletes the channel" do
      channel = create(:iptv_channel)
      expect { delete iptv_channel_path(channel) }.to change(IPTVChannel, :count).by(-1)
      expect(response).to redirect_to(iptv_channels_path)
    end
  end

  describe "POST /tv/import" do
    it "imports channels from a playlist URL" do
      playlist = <<~M3U
        #EXTM3U
        #EXTINF:-1 tvg-id="test.ch" group-title="Live",Test Channel
        https://stream.example.com/live.m3u8
      M3U

      stub_request(:get, "https://example.com/playlist.m3u")
        .to_return(status: 200, body: playlist)

      expect {
        post import_iptv_channels_path, params: { playlist_url: "https://example.com/playlist.m3u" }
      }.to change(IPTVChannel, :count).by(1)

      expect(response).to redirect_to(iptv_channels_path)
      follow_redirect!
      expect(response.body).to include("Imported 1 channels")
    end

    it "handles missing URL" do
      post import_iptv_channels_path, params: { playlist_url: "" }
      expect(response).to redirect_to(iptv_channels_path)
    end

    it "handles fetch errors" do
      stub_request(:get, "https://example.com/bad.m3u")
        .to_raise(HTTP::ConnectionError.new("Connection refused"))

      post import_iptv_channels_path, params: { playlist_url: "https://example.com/bad.m3u" }
      expect(response).to redirect_to(iptv_channels_path)
    end
  end

  describe "feature flag" do
    it "redirects when feature is disabled" do
      Flipper.disable(:iptv)
      get iptv_channels_path
      expect(response).to redirect_to(root_path)
    end
  end
end
