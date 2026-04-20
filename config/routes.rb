Rails.application.routes.draw do
  # SIGNUP
  get  "/signup", to: "users#new"
  post "/signup", to: "users#create"

  get  "/login", to: "users#login"
post "/login", to: "users#create_session"
  # LOGOUT
  delete "/logout", to: "users#destroy"

  # ROOT
  root "users#new"

  # HOME
  get "/home", to: "home#index"

  # Focus Sessions (IMPORTANT: keep consistent naming)
  resources :focus_sessions
  resources :notes, only: %i[index show new create edit update]

  # Intentions (FIXED controller name)
  get "main" => "focus_sessions#main"
  # Activity Tracks
  get "activity_tracking" => "activity_tracks#main_topic", as: :activity_tracking
  post "activity_tracking" => "activity_tracks#create"
  get "details/:id" => "activity_tracks#show", as: :activity_track
  get "main_topic" => "activity_tracks#main_topic"
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
