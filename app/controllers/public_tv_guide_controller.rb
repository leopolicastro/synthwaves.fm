class PublicTvGuideController < ApplicationController
  layout "landing"

  def index
    scope = IPTVChannel.active.with_epg.includes(:iptv_category)

    if params[:category].present?
      @current_category = IPTVCategory.find_by(slug: params[:category])
      scope = scope.where(iptv_category: @current_category) if @current_category
    end

    scope = scope.where("iptv_channels.name LIKE ?", "%#{params[:q]}%") if params[:q].present?
    scope = scope.by_country(params[:country])
    scope = scope.order("iptv_channels.name")

    @channels = scope.all

    @categories = IPTVCategory.where(id: scope.reselect(:iptv_category_id).distinct).order(:name)
    @countries = scope.where.not(country: [nil, ""]).distinct.pluck(:country).sort

    @window_start = parse_window_time || Time.current.beginning_of_hour
    @window_end = @window_start + 6.hours

    tvg_ids = @channels.filter_map(&:tvg_id).reject(&:blank?)
    @programmes_by_channel = if tvg_ids.any?
      EPGProgramme
        .where(channel_id: tvg_ids)
        .in_window(@window_start, @window_end)
        .order(:starts_at)
        .group_by(&:channel_id)
    else
      {}
    end
  end

  private

  def parse_window_time
    return nil unless params[:window_start].present?
    Time.zone.parse(params[:window_start])
  rescue ArgumentError
    nil
  end
end
