class InternetRadioStationsController < ApplicationController
  def index
    @categories = InternetRadioCategory.with_stations.order(:name)
    scope = InternetRadioStation.active.includes(:internet_radio_category)

    if params[:category].present?
      @current_category = InternetRadioCategory.find_by(slug: params[:category])
      scope = scope.where(internet_radio_category: @current_category) if @current_category
    end

    if params[:favorites] == "1"
      favorite_ids = Current.user.favorited_ids_for("InternetRadioStation")
      scope = scope.where(id: favorite_ids)
    end

    scope = scope.search(params[:q])
    scope = scope.by_country(params[:country])
    scope = scope.by_tag(params[:tag])

    scope = case params[:sort]
    when "popular" then scope.popular
    else scope.order(:name)
    end

    @pagy, @stations = pagy(scope, limit: 24)

    @favorited_station_ids = Current.user.favorited_ids_for("InternetRadioStation")

    @countries = InternetRadioStation.active.where.not(country_code: [nil, ""]).distinct.pluck(:country_code).sort
  end

  def show
    @station = InternetRadioStation.find(params[:id])
    @is_favorited = Current.user.favorites.exists?(favorable: @station)
  end

  def edit
    @station = InternetRadioStation.find(params[:id])
  end

  def update
    @station = InternetRadioStation.find(params[:id])

    if @station.update(station_params)
      redirect_to internet_radio_station_path(@station), notice: "Station updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @station = InternetRadioStation.find(params[:id])
    @station.destroy
    redirect_to internet_radio_stations_path, notice: "Station removed."
  end

  def import
    country_code = params[:country_code].to_s.strip.presence
    tag = params[:tag].to_s.strip.presence

    if country_code.blank? && tag.blank?
      redirect_to internet_radio_stations_path, alert: "Please provide a country code or tag."
      return
    end

    result = RadioBrowserSyncService.new(country_code: country_code, tag: tag, limit: 100).call
    redirect_to internet_radio_stations_path, notice: "Imported #{result[:synced]} stations."
  rescue HTTP::Error, HTTP::TimeoutError => e
    redirect_to internet_radio_stations_path, alert: "Failed to fetch stations: #{e.message}"
  end

  def import_url
    url = params[:url].to_s.strip

    if url.blank?
      redirect_to internet_radio_stations_path, alert: "Please provide a URL."
      return
    end

    result = StationUrlImportService.new(url).call

    if result[:error]
      redirect_to internet_radio_stations_path, alert: result[:error]
    else
      redirect_to internet_radio_station_path(result[:station]), notice: "Station added: #{result[:station].name}"
    end
  rescue HTTP::Error, HTTP::TimeoutError => e
    redirect_to internet_radio_stations_path, alert: "Failed to fetch URL: #{e.message}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to internet_radio_stations_path, alert: "Could not save station: #{e.message}"
  end

  private

  def station_params
    params.require(:internet_radio_station).permit(:name, :stream_url, :homepage_url, :favicon_url, :country, :country_code, :language, :tags, :codec, :bitrate)
  end
end
