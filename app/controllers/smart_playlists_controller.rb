class SmartPlaylistsController < ApplicationController
  def index
    @definitions = SmartPlaylistService.all_definitions
  end

  def show
    @playlist_id = params[:id].to_sym
    @definition = SmartPlaylistService::DEFINITIONS[@playlist_id]

    return redirect_to smart_playlists_path unless @definition

    @tracks = SmartPlaylistService.call(user: Current.user, playlist_id: @playlist_id)
  end
end
