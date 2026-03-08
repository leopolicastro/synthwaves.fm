# Subsonic API endpoint definitions shared by both route scopes.
# Registers each endpoint with and without the .view suffix for client compatibility.
SUBSONIC_ENDPOINTS = {
  "ping" => "system#ping",
  "getLicense" => "system#get_license",
  "getMusicFolders" => "browsing#get_music_folders",
  "getIndexes" => "browsing#get_indexes",
  "getArtists" => "browsing#get_artists",
  "getArtist" => "browsing#get_artist",
  "getAlbum" => "browsing#get_album",
  "getSong" => "browsing#get_song",
  "stream" => "media#stream",
  "download" => "media#download",
  "getCoverArt" => "media#get_cover_art",
  "search3" => "search#search3",
  "getAlbumList2" => "lists#get_album_list2",
  "getRandomSongs" => "lists#get_random_songs",
  "getPlaylists" => "playlists#get_playlists",
  "getPlaylist" => "playlists#get_playlist",
  "createPlaylist" => "playlists#create_playlist",
  "deletePlaylist" => "playlists#delete_playlist",
  "star" => "interaction#star",
  "unstar" => "interaction#unstar",
  "getStarred2" => "interaction#get_starred2",
  "scrobble" => "interaction#scrobble"
}.freeze

SUBSONIC_ROUTES = lambda do
  SUBSONIC_ENDPOINTS.each do |endpoint, action|
    get "#{endpoint}.view", to: action
    post "#{endpoint}.view", to: action
    get endpoint, to: action
    post endpoint, to: action
  end
end

# Original /api/rest/ routes
namespace :api do
  namespace :subsonic, path: "/rest", &SUBSONIC_ROUTES
end

# Alias at /rest/ for standard Subsonic client compatibility (e.g. cliamp)
scope "/rest", module: "api/subsonic", &SUBSONIC_ROUTES
