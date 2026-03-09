class IPTVChannelsController < ApplicationController
  before_action :require_feature

  def index
    @categories = IPTVCategory.with_channels.order(:name)
    scope = IPTVChannel.active.includes(:iptv_category)

    if params[:category].present?
      @current_category = IPTVCategory.find_by(slug: params[:category])
      scope = scope.where(iptv_category: @current_category) if @current_category
    end

    scope = scope.search(params[:q])
    scope = scope.by_country(params[:country])
    scope = scope.order(:name)

    @channels = scope.all

    @favorited_channel_ids = Current.user.favorites.where(favorable_type: "IPTVChannel").pluck(:favorable_id).to_set

    @countries = IPTVChannel.active.where.not(country: [nil, ""]).distinct.pluck(:country).sort

    # EPG data for the TV Guide grid
    @window_start = parse_window_time || Time.current.beginning_of_hour
    @window_end = @window_start + 6.hours

    tvg_ids = @channels.filter_map(&:tvg_id).reject(&:blank?)
    if tvg_ids.any?
      @programmes_by_channel = EPGProgramme
        .where(channel_id: tvg_ids)
        .in_window(@window_start, @window_end)
        .order(:starts_at)
        .group_by(&:channel_id)
    else
      @programmes_by_channel = {}
    end
  end

  def show
    @channel = IPTVChannel.find(params[:id])
    @now_playing = @channel.now_playing
    @up_next = @channel.up_next(limit: 5)
    @is_favorited = Current.user.favorites.exists?(favorable: @channel)
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
    redirect_to iptv_channels_path, notice: "Channel removed."
  end

  def import
    url = params[:playlist_url].to_s.strip
    if url.blank?
      redirect_to iptv_channels_path, alert: "Please provide a playlist URL."
      return
    end

    result = IPTVChannelSyncService.import(url)
    redirect_to iptv_channels_path, notice: "Imported #{result[:synced]} channels."
  rescue HTTP::Error, HTTP::TimeoutError => e
    redirect_to iptv_channels_path, alert: "Failed to fetch playlist: #{e.message}"
  end

  private

  def require_feature
    redirect_to root_path, alert: "This feature is not available." unless Flipper.enabled?(:iptv, Current.user)
  end

  def channel_params
    params.require(:iptv_channel).permit(:name, :stream_url, :logo_url, :country, :language, :iptv_category_id, :tvg_id)
  end

  def parse_window_time
    return nil unless params[:window_start].present?

    Time.zone.parse(params[:window_start])
  rescue ArgumentError
    nil
  end
end
