Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :registrations, only: :create
      resource :sessions, only: :create
      resource :current_user, only: :show, path: "me", controller: "current_user"
      resources :meetings, only: :index
    end
  end
end
