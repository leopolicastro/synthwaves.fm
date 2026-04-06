require "rails_helper"

RSpec.describe "PublicTvGuide", type: :request do
  let(:user) { create(:user) }

  describe "GET /tv-guide" do
    it "redirects unauthenticated users to login" do
      get public_tv_guide_path
      expect(response).to redirect_to(new_session_path)
    end

    context "when authenticated" do
      before { login_user(user) }

      it "returns success" do
        get public_tv_guide_path
        expect(response).to have_http_status(:ok)
      end

      it "shows channels with EPG data" do
        channel = create(:iptv_channel, name: "CNN International")
        create(:epg_programme, channel_id: channel.tvg_id, starts_at: 30.minutes.ago, ends_at: 30.minutes.from_now)

        get public_tv_guide_path
        expect(response.body).to include("CNN International")
      end

      it "shows programme titles in the guide" do
        channel = create(:iptv_channel)
        create(:epg_programme, :current, channel_id: channel.tvg_id, title: "Breaking News Live")

        get public_tv_guide_path
        expect(response.body).to include("Breaking News Live")
      end

      it "excludes inactive channels" do
        channel = create(:iptv_channel, :inactive, name: "Dead Channel")
        create(:epg_programme, :current, channel_id: channel.tvg_id)

        get public_tv_guide_path
        expect(response.body).not_to include("Dead Channel")
      end

      it "excludes channels without EPG data" do
        create(:iptv_channel, name: "No EPG Channel")

        get public_tv_guide_path
        expect(response.body).not_to include("No EPG Channel")
      end

      it "shows empty state when no channels exist" do
        get public_tv_guide_path
        expect(response.body).to include("No channels found")
      end

      it "supports search filtering" do
        channel = create(:iptv_channel, name: "ESPN Sports")
        create(:epg_programme, :current, channel_id: channel.tvg_id)

        other = create(:iptv_channel, name: "BBC News")
        create(:epg_programme, :current, channel_id: other.tvg_id)

        get public_tv_guide_path, params: {q: "ESPN"}
        expect(response.body).to include("ESPN Sports")
        expect(response.body).not_to include("BBC News")
      end

      it "supports category filtering" do
        sports = create(:iptv_category, name: "Sports", slug: "sports")
        news = create(:iptv_category, name: "News", slug: "news")

        sports_channel = create(:iptv_channel, name: "ESPN", iptv_category: sports)
        create(:epg_programme, :current, channel_id: sports_channel.tvg_id)

        news_channel = create(:iptv_channel, name: "CNN", iptv_category: news)
        create(:epg_programme, :current, channel_id: news_channel.tvg_id)

        get public_tv_guide_path, params: {category: "sports"}
        expect(response.body).to include("ESPN")
        expect(response.body).not_to include("CNN")
      end

      it "only shows categories that have channels with EPG data" do
        active_cat = create(:iptv_category, name: "Sports", slug: "sports")
        empty_cat = create(:iptv_category, name: "Music", slug: "music")

        channel = create(:iptv_channel, iptv_category: active_cat)
        create(:epg_programme, :current, channel_id: channel.tvg_id)

        create(:iptv_channel, iptv_category: empty_cat)

        get public_tv_guide_path
        expect(response.body).to include("Sports")
        expect(response.body).not_to include(">Music<")
      end

      it "does not include recording functionality" do
        channel = create(:iptv_channel)
        create(:epg_programme, :current, channel_id: channel.tvg_id)

        get public_tv_guide_path
        expect(response.body).not_to include("record")
        expect(response.body).not_to include("recordings")
      end

      it "does not include favorite functionality" do
        channel = create(:iptv_channel)
        create(:epg_programme, :current, channel_id: channel.tvg_id)

        get public_tv_guide_path
        expect(response.body).not_to include("favorites")
      end
    end
  end
end
