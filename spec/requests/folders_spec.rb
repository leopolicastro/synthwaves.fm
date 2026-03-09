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
    it "creates a folder and videos from uploaded files" do
      file1 = fixture_file_upload("test.mp4", "video/mp4")
      file2 = fixture_file_upload("test.mp4", "video/mp4")

      expect {
        post folders_path, params: {
          folder_name: "My Show",
          season_number: "1",
          video_files: [file1, file2]
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
      file = fixture_file_upload("test.mp4", "video/mp4")

      expect {
        post folders_path, params: {
          folder_name: "My Show",
          season_number: "1",
          video_files: [file]
        }
      }.not_to change(Folder, :count)

      expect(existing.videos.count).to eq(1)
    end

    it "parses episode numbers from filenames" do
      file = fixture_file_upload("test.mp4", "video/mp4")
      allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:original_filename).and_return("S01E03 - The Pilot.mp4")

      post folders_path, params: {
        folder_name: "My Show",
        season_number: "1",
        video_files: [file]
      }

      video = Video.last
      expect(video.season_number).to eq(1)
      expect(video.episode_number).to eq(3)
      expect(video.title).to eq("The Pilot")
    end

    it "assigns sequential episode numbers when not parseable" do
      file1 = fixture_file_upload("test.mp4", "video/mp4")
      file2 = fixture_file_upload("test.mp4", "video/mp4")

      post folders_path, params: {
        folder_name: "My Show",
        season_number: "2",
        video_files: [file1, file2]
      }

      videos = Video.last(2).sort_by(&:episode_number)
      expect(videos.map(&:episode_number)).to eq([1, 2])
      expect(videos.map(&:season_number)).to eq([2, 2])
    end

    it "enqueues VideoConversionJob for each video" do
      file1 = fixture_file_upload("test.mp4", "video/mp4")
      file2 = fixture_file_upload("test.mp4", "video/mp4")

      expect {
        post folders_path, params: {
          folder_name: "My Show",
          season_number: "1",
          video_files: [file1, file2]
        }
      }.to have_enqueued_job(VideoConversionJob).exactly(2).times
    end

    it "rejects when folder name is blank" do
      file = fixture_file_upload("test.mp4", "video/mp4")
      post folders_path, params: {folder_name: "", video_files: [file]}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects when no files are uploaded" do
      post folders_path, params: {folder_name: "My Show", video_files: []}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /folders/:id" do
    it "returns success for own folder" do
      folder = create(:folder, user: user)
      get folder_path(folder)
      expect(response).to have_http_status(:ok)
    end

    it "shows videos grouped by season" do
      folder = create(:folder, user: user)
      create(:video, user: user, folder: folder, season_number: 1, episode_number: 1, title: "Pilot")
      create(:video, user: user, folder: folder, season_number: 2, episode_number: 1, title: "Premiere")

      get folder_path(folder)
      expect(response.body).to include("Pilot")
      expect(response.body).to include("Premiere")
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
