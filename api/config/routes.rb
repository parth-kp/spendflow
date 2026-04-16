Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :session, only: %i[create show]
      resources :suppliers
      resources :requisitions do
        member do
          post :submit
          post :approve
          post :reject
          post :cancel
          post :revise
        end
      end
    end
  end
end
