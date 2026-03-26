# Admin routes protected by AdminConstraint
constraints AdminConstraint.new do
  # Below are the routes for madmin
  namespace :madmin, path: :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    resources :albums
    resources :api_keys
    resources :artists
    resources :chats
    resources :favorites
    resources :messages
    resources :models
    resources :play_histories
    resources :playlist_tracks
    resources :playlists
    resources :external_streams
    resources :sessions
    resources :tool_calls
    resources :tracks
    resources :users
    root to: "dashboard#show"
  end
  mount MaintenanceTasks::Engine, at: "/admin/maintenance_tasks"
  mount Flipper::UI.app(Flipper), at: "/admin/flipper"
end
