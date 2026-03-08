Rails.application.routes.draw do
  resources :chats do
    resources :messages, only: [:create]
  end
  resources :models, only: [:index, :show] do
    collection do
      post :refresh
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
  get '/home', to: 'home#show', as: :home
root "static/landing#show"

namespace :static do
  resource :landing, only: [:show], controller: "landing"
end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
