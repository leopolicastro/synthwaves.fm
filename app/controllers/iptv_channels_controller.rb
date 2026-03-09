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

    @pagy, @channels = pagy(:offset, scope, limit: 48)

    @countries = IPTVChannel.active.where.not(country: [nil, ""]).distinct.pluck(:country).sort
  end

  def show
    @channel = IPTVChannel.find(params[:id])
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
end
