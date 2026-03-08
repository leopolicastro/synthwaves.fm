class API::Subsonic::InteractionController < API::Subsonic::BaseController
  def star
    star_items(params[:id], "Track")
    star_items(params[:albumId], "Album")
    star_items(params[:artistId], "Artist")
    render_subsonic
  end

  def unstar
    unstar_items(params[:id], "Track")
    unstar_items(params[:albumId], "Album")
    unstar_items(params[:artistId], "Artist")
    render_subsonic
  end

  def scrobble
    track = Track.find(params[:id])
    current_user.play_histories.create!(track: track, played_at: Time.current)
    render_subsonic
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Song not found")
  end

  private

  def star_items(ids, type)
    return if ids.blank?
    Array(ids).each do |id|
      record = type.constantize.find_by(id: id)
      next unless record
      current_user.favorites.find_or_create_by(favorable: record)
    end
  end

  def unstar_items(ids, type)
    return if ids.blank?
    Array(ids).each do |id|
      current_user.favorites.where(favorable_type: type, favorable_id: id).destroy_all
    end
  end
end
