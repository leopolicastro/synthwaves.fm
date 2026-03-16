require "rails_helper"

RSpec.describe "Subsonic Video API", type: :request do
  let(:user) { create(:user, subsonic_password: "testpass") }
  let(:auth_params) { {u: user.email_address, p: "testpass", v: "1.16.1", c: "test", f: "json"} }

  describe "getVideos" do
    it "returns all ready videos" do
      create(:video, user: user, title: "Video One")
      create(:video, user: user, title: "Video Two")
      create(:video, user: user, title: "Processing", status: "processing")

      get "/api/rest/getVideos", params: auth_params

      json = JSON.parse(response.body)
      videos = json["subsonic-response"]["videos"]["video"]
      expect(videos.length).to eq(2)
      titles = videos.map { |v| v["title"] }
      expect(titles).to contain_exactly("Video One", "Video Two")
    end

    it "filters by folder" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, title: "In folder")
      create(:video, user: user, title: "No folder")

      get "/api/rest/getVideos", params: auth_params.merge(folderId: folder.id)

      json = JSON.parse(response.body)
      videos = json["subsonic-response"]["videos"]["video"]
      expect(videos.length).to eq(1)
      expect(videos.first["title"]).to eq("In folder")
    end

    it "filters by search query" do
      create(:video, user: user, title: "Concert Live")
      create(:video, user: user, title: "Tutorial")

      get "/api/rest/getVideos", params: auth_params.merge(query: "Concert")

      json = JSON.parse(response.body)
      videos = json["subsonic-response"]["videos"]["video"]
      expect(videos.length).to eq(1)
      expect(videos.first["title"]).to eq("Concert Live")
    end

    it "does not return other users' videos" do
      other_user = create(:user)
      create(:video, user: other_user, title: "Other's video")
      create(:video, user: user, title: "My video")

      get "/api/rest/getVideos", params: auth_params

      json = JSON.parse(response.body)
      videos = json["subsonic-response"]["videos"]["video"]
      expect(videos.length).to eq(1)
      expect(videos.first["title"]).to eq("My video")
    end

    it "rejects unauthenticated requests" do
      get "/api/rest/getVideos", params: {f: "json"}

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(40)
    end
  end

  describe "getVideo" do
    it "returns video metadata" do
      folder = create(:folder, user: user, name: "My Series")
      video = create(:video, user: user, folder: folder, title: "Episode 1",
        description: "First ep", duration: 3600.5, width: 1920, height: 1080,
        file_size: 50_000_000, file_format: "mp4", episode_number: 1, season_number: 1)

      get "/api/rest/getVideo", params: auth_params.merge(id: video.id)

      json = JSON.parse(response.body)
      v = json["subsonic-response"]["video"]
      expect(v["id"]).to eq(video.id.to_s)
      expect(v["title"]).to eq("Episode 1")
      expect(v["description"]).to eq("First ep")
      expect(v["duration"]).to eq(3600)
      expect(v["width"]).to eq(1920)
      expect(v["height"]).to eq(1080)
      expect(v["size"]).to eq(50_000_000)
      expect(v["contentType"]).to eq("video/mp4")
      expect(v["folderId"]).to eq(folder.id.to_s)
      expect(v["folderName"]).to eq("My Series")
      expect(v["episodeNumber"]).to eq(1)
      expect(v["seasonNumber"]).to eq(1)
    end

    it "returns error for nonexistent video" do
      get "/api/rest/getVideo", params: auth_params.merge(id: 999999)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "videoStream" do
    it "redirects to the video file URL" do
      video = create(:video, user: user)
      video.file.attach(io: StringIO.new("video"), filename: "test.mp4", content_type: "video/mp4")

      get "/api/rest/videoStream", params: auth_params.merge(id: video.id)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("test.mp4")
    end

    it "returns error for video without file" do
      video = create(:video, user: user)
      video.file.purge

      get "/api/rest/videoStream", params: auth_params.merge(id: video.id)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error for non-ready video" do
      video = create(:video, :processing, user: user)

      get "/api/rest/videoStream", params: auth_params.merge(id: video.id)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("failed")
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end

    it "returns error for nonexistent video" do
      get "/api/rest/videoStream", params: auth_params.merge(id: 999999)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "getVideoThumbnail" do
    it "redirects to the thumbnail URL" do
      video = create(:video, user: user)
      video.thumbnail.attach(io: StringIO.new("thumb"), filename: "thumb.jpg", content_type: "image/jpeg")

      get "/api/rest/getVideoThumbnail", params: auth_params.merge(id: video.id)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("thumb.jpg")
    end

    it "returns 404 when no thumbnail attached" do
      video = create(:video, user: user)
      video.thumbnail.purge if video.thumbnail.attached?

      get "/api/rest/getVideoThumbnail", params: auth_params.merge(id: video.id)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for nonexistent video" do
      get "/api/rest/getVideoThumbnail", params: auth_params.merge(id: 999999)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "savePlaybackPosition" do
    it "creates a new playback position" do
      video = create(:video, user: user)

      expect {
        get "/api/rest/savePlaybackPosition", params: auth_params.merge(id: video.id, position: 125.5)
      }.to change(VideoPlaybackPosition, :count).by(1)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")

      position = VideoPlaybackPosition.last
      expect(position.position).to eq(125.5)
      expect(position.user).to eq(user)
      expect(position.video).to eq(video)
    end

    it "updates an existing playback position" do
      video = create(:video, user: user)
      create(:video_playback_position, user: user, video: video, position: 50.0)

      expect {
        get "/api/rest/savePlaybackPosition", params: auth_params.merge(id: video.id, position: 200.0)
      }.not_to change(VideoPlaybackPosition, :count)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["status"]).to eq("ok")

      expect(VideoPlaybackPosition.find_by(user: user, video: video).position).to eq(200.0)
    end

    it "returns error for nonexistent video" do
      get "/api/rest/savePlaybackPosition", params: auth_params.merge(id: 999999, position: 10.0)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "getPlaybackPosition" do
    it "returns saved position" do
      video = create(:video, user: user)
      create(:video_playback_position, user: user, video: video, position: 75.3)

      get "/api/rest/getPlaybackPosition", params: auth_params.merge(id: video.id)

      json = JSON.parse(response.body)
      pb = json["subsonic-response"]["playbackPosition"]
      expect(pb["id"]).to eq(video.id.to_s)
      expect(pb["position"]).to eq(75.3)
    end

    it "returns 0 when no position saved" do
      video = create(:video, user: user)

      get "/api/rest/getPlaybackPosition", params: auth_params.merge(id: video.id)

      json = JSON.parse(response.body)
      pb = json["subsonic-response"]["playbackPosition"]
      expect(pb["position"]).to eq(0)
    end

    it "returns error for nonexistent video" do
      get "/api/rest/getPlaybackPosition", params: auth_params.merge(id: 999999)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "getFolders" do
    it "returns all folders with video counts" do
      folder1 = create(:folder, user: user, name: "Series A")
      folder2 = create(:folder, user: user, name: "Series B")
      create(:video, user: user, folder: folder1)
      create(:video, user: user, folder: folder1)
      create(:video, user: user, folder: folder2)
      create(:video, :processing, user: user, folder: folder2)

      get "/api/rest/getFolders", params: auth_params

      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["folders"]["folder"]
      expect(folders.length).to eq(2)

      a = folders.find { |f| f["name"] == "Series A" }
      b = folders.find { |f| f["name"] == "Series B" }
      expect(a["videoCount"]).to eq(2)
      expect(b["videoCount"]).to eq(1)
    end

    it "does not return other users' folders" do
      other_user = create(:user)
      create(:folder, user: other_user, name: "Other folder")
      create(:folder, user: user, name: "My folder")

      get "/api/rest/getFolders", params: auth_params

      json = JSON.parse(response.body)
      folders = json["subsonic-response"]["folders"]["folder"]
      expect(folders.length).to eq(1)
      expect(folders.first["name"]).to eq("My folder")
    end
  end

  describe "getFolder" do
    it "returns folder with its videos" do
      folder = create(:folder, user: user, name: "My Series")
      create(:video, user: user, folder: folder, title: "Ep 1", season_number: 1, episode_number: 1)
      create(:video, user: user, folder: folder, title: "Ep 2", season_number: 1, episode_number: 2)
      create(:video, :processing, user: user, folder: folder, title: "Ep 3")

      get "/api/rest/getFolder", params: auth_params.merge(id: folder.id)

      json = JSON.parse(response.body)
      f = json["subsonic-response"]["folder"]
      expect(f["id"]).to eq(folder.id.to_s)
      expect(f["name"]).to eq("My Series")
      expect(f["video"].length).to eq(2)
      expect(f["video"].map { |v| v["title"] }).to eq(["Ep 1", "Ep 2"])
    end

    it "returns error for nonexistent folder" do
      get "/api/rest/getFolder", params: auth_params.merge(id: 999999)

      json = JSON.parse(response.body)
      expect(json["subsonic-response"]["error"]["code"]).to eq(70)
    end
  end

  describe "XML response format" do
    it "returns valid XML for getVideos" do
      create(:video, user: user, title: "XML Video")

      get "/api/rest/getVideos", params: auth_params.except(:f)

      expect(response.content_type).to include("xml")
      doc = Nokogiri::XML(response.body)
      expect(doc.at("subsonic-response")["status"]).to eq("ok")
      expect(doc.at("video")["title"]).to eq("XML Video")
    end
  end
end
