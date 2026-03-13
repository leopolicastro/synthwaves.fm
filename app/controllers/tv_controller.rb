class TvController < ApplicationController
  def show
    @available_tabs = available_tabs
    @tab = params[:tab].presence_in(@available_tabs) || "guide"

    case @tab
    when "guide"
      load_guide
    when "videos"
      load_videos
    when "recordings"
      load_recordings
    when "podcasts"
      load_podcasts
    end
  end

  private

  def available_tabs
    %w[guide videos recordings podcasts]
  end

  def load_guide
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

    @favorited_channel_ids = Current.user.favorited_ids_for("IPTVChannel")

    @countries = IPTVChannel.active.where.not(country: [nil, ""]).distinct.pluck(:country).sort

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

    all_programme_ids = @programmes_by_channel.values.flatten.map(&:id)
    @recording_by_programme_id = if all_programme_ids.any?
      Current.user.recordings
        .where(epg_programme_id: all_programme_ids)
        .where.not(status: %w[failed cancelled])
        .pluck(:epg_programme_id, :status)
        .to_h
    else
      {}
    end
  end

  def load_videos
    @query = params[:q]
    @folders = Current.user.folders.search(@query).order(:name)
    scope = Current.user.videos.ready.standalone.search(@query).order(created_at: :desc)
    @pagy, @videos = pagy(scope)
  end

  def load_recordings
    @query = params[:q]
    @status = params[:status]
    @sort = sort_column(Recording, default: "created_at")
    @direction = sort_direction(default: "desc")
    scope = Current.user.recordings.includes(:iptv_channel)
              .search(@query)
              .by_status(@status)
              .order(@sort => @direction)
    @pagy, @recordings = pagy(scope)
  end

  def load_podcasts
    @query = params[:q]
    scope = Current.user.artists.podcast.includes(albums: {cover_image_attachment: :blob})
      .search(@query)
      .order(:name)
    @pagy, @podcasts = pagy(:offset, scope)
  end

  def parse_window_time
    return nil unless params[:window_start].present?

    Time.zone.parse(params[:window_start])
  rescue ArgumentError
    nil
  end
end
