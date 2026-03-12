require "rails_helper"

RSpec.describe "Folders", type: :request do
  let(:user) { create(:user) }

  before { login_user(user) }

  describe "GET /folders/new" do
    it "returns success" do
      get new_folder_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /folders" do
    def create_video_blob(filename: "test.mp4")
      ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join("spec/fixtures/files/test.mp4").open,
        filename: filename,
        content_type: "video/mp4"
      )
    end

    it "creates a folder and videos from uploaded files" do
      blob1 = create_video_blob(filename: "Episode 1.mp4")
      blob2 = create_video_blob(filename: "Episode 2.mp4")

      expect {
        post folders_path, params: {
          folder_name: "My Show",
          season_number: "1",
          signed_blob_ids: [blob1.signed_id, blob2.signed_id],
          filenames: ["Episode 1.mp4", "Episode 2.mp4"]
        }
      }.to change(Folder, :count).by(1)
        .and change(Video, :count).by(2)

      folder = Folder.last
      expect(folder.name).to eq("My Show")
      expect(folder.user).to eq(user)
      expect(folder.videos.count).to eq(2)
      expect(response).to redirect_to(folder_path(folder))
    end

    it "reuses an existing folder with the same name" do
      existing = create(:folder, user: user, name: "My Show")
      blob = create_video_blob

      expect {
        post folders_path, params: {
          folder_name: "My Show",
          season_number: "1",
          signed_blob_ids: [blob.signed_id],
          filenames: ["test.mp4"]
        }
      }.not_to change(Folder, :count)

      expect(existing.videos.count).to eq(1)
    end

    it "parses episode numbers from filenames" do
      blob = create_video_blob(filename: "S01E03 - The Pilot.mp4")

      post folders_path, params: {
        folder_name: "My Show",
        season_number: "1",
        signed_blob_ids: [blob.signed_id],
        filenames: ["S01E03 - The Pilot.mp4"]
      }

      video = Video.last
      expect(video.season_number).to eq(1)
      expect(video.episode_number).to eq(3)
      expect(video.title).to eq("The Pilot")
    end

    it "assigns sequential episode numbers when not parseable" do
      blob1 = create_video_blob(filename: "random_file.mp4")
      blob2 = create_video_blob(filename: "another_file.mp4")

      post folders_path, params: {
        folder_name: "My Show",
        season_number: "2",
        signed_blob_ids: [blob1.signed_id, blob2.signed_id],
        filenames: ["random_file.mp4", "another_file.mp4"]
      }

      videos = Video.last(2).sort_by(&:episode_number)
      expect(videos.map(&:episode_number)).to eq([1, 2])
      expect(videos.map(&:season_number)).to eq([2, 2])
    end

    it "enqueues VideoConversionJob for each video" do
      blob1 = create_video_blob
      blob2 = create_video_blob

      expect {
        post folders_path, params: {
          folder_name: "My Show",
          season_number: "1",
          signed_blob_ids: [blob1.signed_id, blob2.signed_id],
          filenames: ["test1.mp4", "test2.mp4"]
        }
      }.to have_enqueued_job(VideoConversionJob).exactly(2).times
    end

    it "rejects when folder name is blank" do
      blob = create_video_blob
      post folders_path, params: {folder_name: "", signed_blob_ids: [blob.signed_id], filenames: ["test.mp4"]}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when no files are uploaded" do
      post folders_path, params: {folder_name: "My Show", signed_blob_ids: []}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /folders/:id" do
    it "returns success for own folder" do
      folder = create(:folder, user: user)
      get folder_path(folder)
      expect(response).to have_http_status(:ok)
    end

    it "shows videos from all seasons" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, season_number: 1, episode_number: 1, title: "Pilot")
      create(:video, user: user, folder: folder, season_number: 2, episode_number: 1, title: "Premiere")

      get folder_path(folder)
      expect(response.body).to include("Pilot")
      expect(response.body).to include("Premiere")
    end

    it "paginates when more than 24 videos" do
      folder = create(:folder, user: user)
      25.times do |i|
        create(:video, user: user, folder: folder, season_number: 1, episode_number: i + 1, title: "Episode #{i + 1}")
      end

      get folder_path(folder)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("page=2")
    end

    it "filters by season" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, season_number: 1, episode_number: 1, title: "S1 Pilot")
      create(:video, user: user, folder: folder, season_number: 2, episode_number: 1, title: "S2 Premiere")

      get folder_path(folder, season: "1")
      expect(response.body).to include("S1 Pilot")
      expect(response.body).not_to include("S2 Premiere")
    end

    it "filters by search query" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, title: "Pilot")
      create(:video, user: user, folder: folder, title: "Finale")

      get folder_path(folder, q: "Pilot")
      expect(response.body).to include("Pilot")
      expect(response.body).not_to include("Finale")
    end

    it "sorts by title" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, title: "Zebra")
      create(:video, user: user, folder: folder, title: "Alpha")

      get folder_path(folder, sort: "title", direction: "asc")
      expect(response).to have_http_status(:ok)
      expect(response.body.index("Alpha")).to be < response.body.index("Zebra")
    end

    it "falls back to default sort for invalid sort param" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder)

      get folder_path(folder, sort: "bogus")
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's folder" do
      other_user = create(:user)
      folder = create(:folder, user: other_user)

      get folder_path(folder)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /folders/:id/edit" do
    it "returns success" do
      folder = create(:folder, user: user)
      get edit_folder_path(folder)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /folders/:id" do
    it "updates the folder" do
      folder = create(:folder, user: user, name: "Old Name")
      patch folder_path(folder), params: {folder: {name: "New Name", description: "Updated"}}

      folder.reload
      expect(folder.name).to eq("New Name")
      expect(folder.description).to eq("Updated")
      expect(response).to redirect_to(folder_path(folder))
    end

    it "rejects blank name" do
      folder = create(:folder, user: user)
      patch folder_path(folder), params: {folder: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /folders/:id" do
    it "deletes the folder but keeps videos" do
      folder = create(:folder, user: user)
      video = create(:video, user: user, folder: folder)

      expect { delete folder_path(folder) }.to change(Folder, :count).by(-1)
      expect(Video.exists?(video.id)).to be true
      expect(video.reload.folder_id).to be_nil
      expect(response).to redirect_to(tv_path(tab: "videos"))
    end
  end
end
