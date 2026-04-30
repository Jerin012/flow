Rails.application.routes.draw do
  # SIGNUP
  get  "/signup", to: "users#new"
  post "/signup", to: "users#create"

  get  "/login", to: "users#login"
  post "/login", to: "users#create_session"
  # LOGOUT
  delete "/logout", to: "users#destroy"

  # ROOT
  root "dashboard#show"
  get "/dashboard", to: "dashboard#show", as: :dashboard

  # Focus Sessions (IMPORTANT: keep consistent naming)
  resources :focus_sessions, only: %i[new create show] do
    member do
      patch :activate
      patch :sync_state
      patch :reset_state
    end
  end
  get "/focus_sessions/:focus_session_id/note", to: "notes#focus_session_note", as: :focus_session_note
  resources :notes, only: %i[index show new create edit update destroy] do
    collection do
      get :recycle_bin
    end

    member do
      patch :restore
      delete :destroy_forever, path: "permanent"
    end
  end

  # Intentions (FIXED controller name)
  get "main" => "focus_sessions#main"
  # Activity Tracks
  get "activity_tracking" => "activity_tracks#main_topic", as: :activity_tracking
  post "activity_tracking" => "activity_tracks#create"
  get "details/:id" => "activity_tracks#show", as: :activity_track
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
