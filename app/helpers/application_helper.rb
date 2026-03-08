module ApplicationHelper
  def current_user_playlists
    @current_user_playlists ||= Current.user&.playlists&.order(:name) || []
  end
end
