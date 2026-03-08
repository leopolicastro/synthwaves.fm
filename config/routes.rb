Rails.application.routes.draw do
  constraints AdminConstraint.new do
    mount Quarterdeck::Engine => "/quarterdeck"
  end

  resources :chats do
    resources :messages, only: [:create]
  end
  resources :models, only: [:index, :show] do
    collection do
      post :refresh
    end
  end
  # Music routes
  resources :artists, only: [:index, :show]
  resources :albums, only: [:index, :show]
  resources :tracks, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member { get :stream }
  end
  resources :playlists
  resources :favorites, only: [:index, :create, :destroy]
  resources :play_histories, only: [:index, :create]
  get :search, to: "search#index"
  get :library, to: "library#show"

  # Subsonic API
  namespace :api do
    namespace :subsonic, path: "/rest" do
      get "ping.view", to: "system#ping"
      post "ping.view", to: "system#ping"
      get "getLicense.view", to: "system#get_license"
      post "getLicense.view", to: "system#get_license"

      get "getMusicFolders.view", to: "browsing#get_music_folders"
      post "getMusicFolders.view", to: "browsing#get_music_folders"
      get "getIndexes.view", to: "browsing#get_indexes"
      post "getIndexes.view", to: "browsing#get_indexes"
      get "getArtists.view", to: "browsing#get_artists"
      post "getArtists.view", to: "browsing#get_artists"
      get "getArtist.view", to: "browsing#get_artist"
      post "getArtist.view", to: "browsing#get_artist"
      get "getAlbum.view", to: "browsing#get_album"
      post "getAlbum.view", to: "browsing#get_album"
      get "getSong.view", to: "browsing#get_song"
      post "getSong.view", to: "browsing#get_song"

      get "stream.view", to: "media#stream"
      post "stream.view", to: "media#stream"
      get "getCoverArt.view", to: "media#get_cover_art"
      post "getCoverArt.view", to: "media#get_cover_art"

      get "search3.view", to: "search#search3"
      post "search3.view", to: "search#search3"

      get "getAlbumList2.view", to: "lists#get_album_list2"
      post "getAlbumList2.view", to: "lists#get_album_list2"
      get "getRandomSongs.view", to: "lists#get_random_songs"
      post "getRandomSongs.view", to: "lists#get_random_songs"

      get "getPlaylists.view", to: "playlists#get_playlists"
      post "getPlaylists.view", to: "playlists#get_playlists"
      get "getPlaylist.view", to: "playlists#get_playlist"
      post "getPlaylist.view", to: "playlists#get_playlist"
      get "createPlaylist.view", to: "playlists#create_playlist"
      post "createPlaylist.view", to: "playlists#create_playlist"
      get "deletePlaylist.view", to: "playlists#delete_playlist"
      post "deletePlaylist.view", to: "playlists#delete_playlist"

      get "star.view", to: "interaction#star"
      post "star.view", to: "interaction#star"
      get "unstar.view", to: "interaction#unstar"
      post "unstar.view", to: "interaction#unstar"
      get "scrobble.view", to: "interaction#scrobble"
      post "scrobble.view", to: "interaction#scrobble"
    end
  end

  draw :madmin
  # API routes
  namespace :api do
    namespace :v1 do
      post "auth/token", to: "auth#create"
    end
  end

  # API keys management
  resources :api_keys, only: [:index, :new, :create, :destroy]

  resource :profile, only: [:show, :edit, :update]
  resource :registration, only: [:new, :create]
  resource :session
  resources :passwords, param: :token
  get "/home", to: "home#show", as: :home
  root "library#show"

  namespace :static do
    resource :landing, only: [:show], controller: "landing"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
