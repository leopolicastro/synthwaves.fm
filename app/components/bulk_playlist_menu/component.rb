module BulkPlaylistMenu
  class Component < ViewComponent::Base
    def initialize(tracks:, playlists:, new_playlist_name: "New Playlist")
      @tracks = tracks
      @playlists = playlists
      @new_playlist_name = new_playlist_name
    end

    def render?
      tracks.any?
    end

    private

    attr_reader :tracks, :playlists, :new_playlist_name

    def track_ids
      tracks.map(&:id)
    end
  end
end
