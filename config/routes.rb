Rails.application.routes.draw do
  # Locale switching
  get "locale/:locale", to: "application#set_locale", as: :set_locale

  # Dashboard routes
  get "dashboard", to: "dashboard#index"
  get "dashboard/client"
  get "dashboard/owner"
  get "dashboard/admin", to: redirect('/admin')

  # Admin namespace
  namespace :admin do
    root to: 'dashboard#index'
    resources :users
    get 'settings', to: 'settings#index', as: :settings
  end

  # Subscription routes
  resources :subscriptions, only: [:index, :new, :create, :show] do
    collection do
      post :start_trial
      post :verify_payment  # Server-side payment verification endpoint
      get :callback         # Moyasar callback URL after payment
    end
    member do
      get :success
      delete :cancel
    end
  end

  # Moyasar webhook endpoint
  post 'moyasar/webhooks', to: 'moyasar_webhooks#create'

  resources :queue_tickets
  resources :calendar_events
  resources :categories

  resources :businesses do
    member do
      get :calendar
    end
    resources :services do
      member do
        get :available_slots
      end
      resources :bookings, only: [:new, :create]
    end
  end

  resources :bookings, only: [:index, :show, :edit, :update, :destroy] do
    member do
      patch :cancel
    end
  end
  get "pages/profile", to: "pages#profile"
  get "pages/home", to: "pages#home"

  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end
