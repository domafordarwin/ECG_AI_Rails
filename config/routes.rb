Rails.application.routes.draw do
  root "pages#index"
  get "upload", to: "pages#upload"
  get "analysis", to: "pages#analysis"
  get "detailed", to: "pages#detailed"
  get "history", to: "pages#history"
  get "feedback", to: "pages#feedback"

  namespace :api do
    namespace :v1 do
      post "analyze", to: "analyze#create"
      get "health", to: "analyze#health"
    end
  end

  # Standard health check remains accessible for ops tooling.
  get "up" => "rails/health#show", as: :rails_health_check
end
