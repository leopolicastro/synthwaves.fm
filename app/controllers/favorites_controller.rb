class FavoritesController < ApplicationController
  def index
    @favorites = Current.user.favorites.includes(:favorable).order(created_at: :desc)
  end

  def create
    favorable = find_favorable
    favorite = Current.user.favorites.find_or_create_by(favorable: favorable)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("favorite_#{favorable.class.name.downcase}_#{favorable.id}", partial: "favorites/button", locals: {favorable: favorable, favorited: true}) }
      format.html { redirect_back fallback_location: library_path, notice: "Added to favorites." }
    end
  end

  def destroy
    favorite = Current.user.favorites.find(params[:id])
    favorable = favorite.favorable
    favorite.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("favorite_#{favorable.class.name.downcase}_#{favorable.id}", partial: "favorites/button", locals: {favorable: favorable, favorited: false}) }
      format.html { redirect_back fallback_location: library_path, notice: "Removed from favorites." }
    end
  end

  private

  def find_favorable
    case params[:favorable_type]
    when "Track" then Track.find(params[:favorable_id])
    when "Album" then Album.find(params[:favorable_id])
    when "Artist" then Artist.find(params[:favorable_id])
    else raise ActiveRecord::RecordNotFound
    end
  end
end
