# Admin routes protected by AdminConstraint
constraints AdminConstraint.new do
  # Below are the routes for madmin
  namespace :madmin, path: :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    resources :sessions
    resources :users
    resources :api_keys
    root to: "dashboard#show"
  end
  mount MaintenanceTasks::Engine, at: "/admin/maintenance_tasks"
  mount Flipper::UI.app(Flipper), at: "/admin/flipper"
end
