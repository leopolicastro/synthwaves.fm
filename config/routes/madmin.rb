# Admin routes protected by AdminConstraint
constraints AdminConstraint.new do
  # Below are the routes for madmin
  namespace :madmin, path: :admin do
    resources :sessions
    resources :users
    resources :api_keys
    root to: "dashboard#show"
  end
end
