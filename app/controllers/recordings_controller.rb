class RecordingsController < ApplicationController
  include FeatureFlagged
  require_feature :iptv

  def index
    @query = params[:q]
    @status = params[:status]
    @sort = sort_column(Recording, default: "created_at")
    @direction = sort_direction(default: "desc")
    scope = Current.user.recordings.includes(:iptv_channel)
              .search(@query)
              .by_status(@status)
              .order(@sort => @direction)
    @pagy, @recordings = pagy(:offset, scope)
  end

  def show
    @recording = Current.user.recordings.find(params[:id])
  end

  def create
    channel = IPTVChannel.find(params[:iptv_channel_id])
    programme = EPGProgramme.find(params[:epg_programme_id])

    recording = Recording.active.find_by(iptv_channel: channel, epg_programme: programme)

    if recording
      Current.user.user_recordings.find_or_create_by!(recording: recording)
      redirect_to recordings_path, notice: "Recording already scheduled: #{recording.title}"
      return
    end

    recording = Recording.create!(
      iptv_channel: channel,
      epg_programme: programme,
      title: programme.title,
      starts_at: [programme.starts_at, Time.current].max,
      ends_at: programme.ends_at
    )
    Current.user.user_recordings.create!(recording: recording)

    if recording.starts_at <= Time.current
      StreamRecordingJob.perform_later(recording.id)
    else
      StreamRecordingJob.set(wait_until: recording.starts_at).perform_later(recording.id)
    end

    redirect_to recordings_path, notice: "Recording scheduled: #{recording.title}"
  end

  def cancel
    recording = Current.user.recordings.find(params[:id])

    if recording.cancellable?
      Current.user.user_recordings.find_by!(recording: recording).destroy
      if recording.user_recordings.none?
        recording.update!(status: "cancelled")
        recording.broadcast_status
      end
      redirect_to recordings_path, notice: "Recording cancelled."
    else
      redirect_to recordings_path, alert: "This recording cannot be cancelled."
    end
  end

  def destroy
    recording = Current.user.recordings.find(params[:id])
    Current.user.user_recordings.find_by!(recording: recording).destroy

    if recording.user_recordings.none?
      recording.file.purge if recording.file.attached?
      recording.destroy
    end

    redirect_to recordings_path, notice: "Recording removed."
  end

  def file
    recording = Current.user.recordings.find(params[:id])

    unless recording.ready? && recording.file.attached?
      redirect_to recording_path(recording), alert: "Recording is not ready yet."
      return
    end

    redirect_to rails_blob_path(recording.file, disposition: "attachment", filename: recording.filename), allow_other_host: true
  end

end
