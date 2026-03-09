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
  get :music, to: "music#show"
  resources :artists, only: [:index, :show]
  resources :albums, only: [:index, :show, :update] do
    post :create_playlist, on: :member
    post :refresh, on: :member
    post :fetch_cover, on: :member
  end
  resources :tracks, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      get :stream
      get :download
    end
  end
  resources :downloads, only: [:index, :create, :show] do
    member { get :file }
  end
  resources :playlists do
    resources :tracks, controller: "playlist_tracks", only: [:create, :destroy], as: :tracks
  end
  resources :podcasts, only: [:show]
  resources :radio_stations, only: [:index, :new, :create, :destroy] do
    resource :stream, only: [:show], controller: "radio_streams"
  end
  get :tv, to: "tv#show"
  resources :iptv_channels, only: [:show, :new, :create, :edit, :update, :destroy], path: "tv/channels" do
    post :import, on: :collection
    post :sync_epg, on: :member
  end
  resources :folders, only: [:show, :new, :create, :edit, :update, :destroy]
  resources :videos, only: [:new, :create, :show, :edit, :update, :destroy] do
    member do
      get :stream
    end
  end
  resources :internet_radio_stations, only: [:index, :show, :edit, :update, :destroy], path: "internet-radio" do
    collection do
      post :import
      post :import_url
    end
    resource :stream, only: [:show], controller: "internet_radio_streams"
  end
  resources :recordings, only: [:index, :show, :create, :destroy] do
    member do
      post :cancel
      get :file
    end
  end
  resources :youtube_imports, only: [:new, :create]
  resources :favorites, only: [:index, :create, :destroy]
  resources :play_histories, only: [:index, :create]
  get "search/dropdown", to: "search#dropdown"
  get :search, to: "search#index"
  get :library, to: "library#show"
  draw :subsonic

  draw :madmin
  # API routes
  namespace :api do
    namespace :v1 do
      post "auth/token", to: "auth#create"
    end
    namespace :import do
      resources :tracks, only: [:create]
      resources :playlists, only: [:create]
    end
  end

  # API keys management
  resources :api_keys, only: [:index, :new, :create, :destroy]

  resource :profile, only: [:show, :edit, :update]
  resource :registration, only: [:new, :create]
  resource :session
  resources :passwords, param: :token
  get "/home", to: "home#show", as: :home
  root "static/landing#show"

  namespace :static do
    resource :landing, only: [:show], controller: "landing"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", :as => :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
