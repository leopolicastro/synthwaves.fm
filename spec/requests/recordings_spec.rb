require "rails_helper"

RSpec.describe "Recordings", type: :request do
  let(:user) { create(:user) }
  let(:channel) { create(:iptv_channel) }

  before do
    login_user(user)
    Flipper.enable(:iptv)
  end

  def create_recording_for(user, **attrs)
    recording = create(:recording, **attrs)
    create(:user_recording, user: user, recording: recording)
    recording
  end

  describe "GET /recordings" do
    it "lists the current user's recordings" do
      recording = create_recording_for(user)

      get recordings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("recording_#{recording.id}")
    end

    it "does not show other users' recordings" do
      other_user = create(:user)
      other_recording = create_recording_for(other_user)

      get recordings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("recording_#{other_recording.id}")
    end

    it "filters by search query matching title" do
      match = create_recording_for(user, title: "Evening News")
      no_match = create_recording_for(user, title: "Morning Show")

      get recordings_path, params: { q: "News" }

      expect(response.body).to include("recording_#{match.id}")
      expect(response.body).not_to include("recording_#{no_match.id}")
    end

    it "searches by channel name" do
      channel = create(:iptv_channel, name: "BBC One")
      match = create_recording_for(user, iptv_channel: channel)
      no_match = create_recording_for(user, title: "Other Show")

      get recordings_path, params: { q: "BBC" }

      expect(response.body).to include("recording_#{match.id}")
      expect(response.body).not_to include("recording_#{no_match.id}")
    end

    it "shows empty state with query context" do
      get recordings_path, params: { q: "nonexistent" }

      expect(response.body).to include("No recordings found")
      expect(response.body).to include("nonexistent")
    end

    it "filters by status" do
      scheduled = create_recording_for(user, status: "scheduled")
      ready = create_recording_for(user, **attributes_for(:recording, :ready))

      get recordings_path, params: { status: "scheduled" }

      expect(response.body).to include("recording_#{scheduled.id}")
      expect(response.body).not_to include("recording_#{ready.id}")
    end

    it "sorts by title ascending" do
      bravo = create_recording_for(user, title: "Bravo Show")
      alpha = create_recording_for(user, title: "Alpha Show")

      get recordings_path, params: { sort: "title", direction: "asc" }

      expect(response.body.index("recording_#{alpha.id}")).to be < response.body.index("recording_#{bravo.id}")
    end

    it "default sort is created_at descending" do
      old_rec = create_recording_for(user, title: "Old Recording", created_at: 2.days.ago)
      new_rec = create_recording_for(user, title: "New Recording", created_at: 1.day.ago)

      get recordings_path

      expect(response.body.index("recording_#{new_rec.id}")).to be < response.body.index("recording_#{old_rec.id}")
    end

    it "requires authentication" do
      reset!
      get recordings_path
      expect(response).to redirect_to(new_session_path)
    end

    it "requires iptv feature flag" do
      Flipper.disable(:iptv)

      get recordings_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /recordings/:id" do
    it "shows the recording detail page" do
      recording = create_recording_for(user)

      get recording_path(recording)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(recording.title)
    end

    it "does not show another user's recording" do
      other_user = create(:user)
      other_recording = create_recording_for(other_user)

      get recording_path(other_recording)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /recordings" do
    let(:programme) { create(:epg_programme, :current, channel_id: channel.tvg_id) }

    it "creates a recording from an EPG programme and enqueues job" do
      expect {
        post recordings_path, params: {iptv_channel_id: channel.id, epg_programme_id: programme.id}
      }.to change(Recording, :count).by(1)
        .and change(UserRecording, :count).by(1)
        .and have_enqueued_job(StreamRecordingJob)

      recording = Recording.last
      expect(recording.title).to eq(programme.title)
      expect(recording.iptv_channel).to eq(channel)
      expect(recording.epg_programme).to eq(programme)
      expect(recording.users).to include(user)
      expect(recording.status).to eq("scheduled")
    end

    it "reuses existing active recording for same programme" do
      existing = create(:recording, iptv_channel: channel, epg_programme: programme, status: "scheduled")

      expect {
        post recordings_path, params: {iptv_channel_id: channel.id, epg_programme_id: programme.id}
      }.to change(UserRecording, :count).by(1)
        .and change(Recording, :count).by(0)

      expect(existing.users.reload).to include(user)
      expect(response).to redirect_to(recordings_path)
      expect(flash[:notice]).to include("already scheduled")
    end

    it "schedules future recordings with wait_until" do
      future_programme = create(:epg_programme, :upcoming, channel_id: channel.tvg_id)

      post recordings_path, params: {iptv_channel_id: channel.id, epg_programme_id: future_programme.id}

      expect(StreamRecordingJob).to have_been_enqueued
      expect(response).to redirect_to(recordings_path)
    end

    it "redirects to recordings index with notice" do
      post recordings_path, params: {iptv_channel_id: channel.id, epg_programme_id: programme.id}

      expect(response).to redirect_to(recordings_path)
      expect(flash[:notice]).to include("Recording scheduled")
    end
  end

  describe "POST /recordings/:id/cancel" do
    it "cancels a scheduled recording when user is last subscriber" do
      recording = create_recording_for(user, status: "scheduled")

      post cancel_recording_path(recording)

      recording.reload
      expect(recording.status).to eq("cancelled")
      expect(response).to redirect_to(recordings_path)
    end

    it "removes user but keeps recording when other users are subscribed" do
      recording = create_recording_for(user, status: "scheduled")
      other_user = create(:user)
      create(:user_recording, user: other_user, recording: recording)

      post cancel_recording_path(recording)

      recording.reload
      expect(recording.status).to eq("scheduled")
      expect(recording.users).not_to include(user)
      expect(recording.users).to include(other_user)
    end

    it "does not cancel a ready recording" do
      recording = create_recording_for(user, **attributes_for(:recording, :ready))

      post cancel_recording_path(recording)

      recording.reload
      expect(recording.status).to eq("ready")
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /recordings/:id" do
    it "removes user association and destroys recording when last subscriber" do
      recording = create_recording_for(user)

      expect {
        delete recording_path(recording)
      }.to change(Recording, :count).by(-1)
        .and change(UserRecording, :count).by(-1)

      expect(response).to redirect_to(recordings_path)
    end

    it "removes user association but keeps recording for other users" do
      recording = create_recording_for(user)
      other_user = create(:user)
      create(:user_recording, user: other_user, recording: recording)

      expect {
        delete recording_path(recording)
      }.to change(UserRecording, :count).by(-1)
        .and change(Recording, :count).by(0)

      expect(recording.reload.users).to include(other_user)
    end

    it "does not delete another user's recording" do
      other_user = create(:user)
      other_recording = create_recording_for(other_user)

      expect {
        delete recording_path(other_recording)
      }.not_to change(Recording, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /recordings/:id/file" do
    it "redirects to the file when ready" do
      recording = create_recording_for(user, **attributes_for(:recording, :ready))
      recording.file.attach(
        io: StringIO.new("fake video content"),
        filename: "test.mp4",
        content_type: "video/mp4"
      )

      get file_recording_path(recording)

      expect(response).to have_http_status(:redirect)
    end

    it "redirects with alert when not ready" do
      recording = create_recording_for(user, status: "processing", starts_at: 1.hour.ago, ends_at: 10.minutes.ago)

      get file_recording_path(recording)

      expect(response).to redirect_to(recording_path(recording))
      expect(flash[:alert]).to eq("Recording is not ready yet.")
    end
  end
end
