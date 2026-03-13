class IPTVChannelsController < ApplicationController
  def show
    @channel = IPTVChannel.find(params[:id])
    @now_playing = @channel.now_playing
    @up_next = @channel.up_next(limit: 5)
    @is_favorited = Current.user.favorites.exists?(favorable: @channel)

    programme_ids = [@now_playing, *@up_next].compact.map(&:id)
    if programme_ids.any?
      @recording_by_programme_id = Current.user.recordings
        .where(epg_programme_id: programme_ids)
        .where.not(status: %w[failed cancelled])
        .pluck(:epg_programme_id, :status)
        .to_h
    else
      @recording_by_programme_id = {}
    end
  end

  def new
    @channel = IPTVChannel.new
    @categories = IPTVCategory.order(:name)
  end

  def create
    @channel = IPTVChannel.new(channel_params)

    if @channel.save
      redirect_to iptv_channel_path(@channel), notice: "Channel added."
    else
      @categories = IPTVCategory.order(:name)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @channel = IPTVChannel.find(params[:id])
    @categories = IPTVCategory.order(:name)
  end

  def update
    @channel = IPTVChannel.find(params[:id])

    if @channel.update(channel_params)
      redirect_to iptv_channel_path(@channel), notice: "Channel updated."
    else
      @categories = IPTVCategory.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @channel = IPTVChannel.find(params[:id])
    @channel.destroy
    redirect_to tv_path, notice: "Channel removed."
  end

  def sync_epg
    @channel = IPTVChannel.find(params[:id])

    if @channel.epg_url.blank?
      redirect_to iptv_channel_path(@channel), alert: "No EPG URL configured. Edit the channel to add one."
      return
    end

    count = EPGSyncService.sync_channel(@channel)
    redirect_to iptv_channel_path(@channel), notice: "Synced #{count} programmes."
  rescue HTTP::Error, HTTP::TimeoutError => e
    redirect_to iptv_channel_path(@channel), alert: "EPG sync failed: #{e.message}"
  end

  def import
    url = params[:playlist_url].to_s.strip
    if url.blank?
      redirect_to tv_path, alert: "Please provide a playlist URL."
      return
    end

    result = IPTVChannelSyncService.import(url)
    redirect_to tv_path, notice: "Imported #{result[:synced]} channels."
  rescue HTTP::Error, HTTP::TimeoutError => e
    redirect_to tv_path, alert: "Failed to fetch playlist: #{e.message}"
  end

  private

  def channel_params
    params.require(:iptv_channel).permit(:name, :stream_url, :logo_url, :country, :language, :iptv_category_id, :tvg_id, :epg_url)
  end

  def parse_window_time
    return nil unless params[:window_start].present?

    Time.zone.parse(params[:window_start])
  rescue ArgumentError
    nil
  end
end
