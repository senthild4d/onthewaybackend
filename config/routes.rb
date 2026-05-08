Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      get 'currencies', to: 'currencies#index'

      # Legal / policy documents (public URLs for in-app display)
      get 'legal_documents', to: 'legal_documents#index'
      get 'legal_documents/:kind', to: 'legal_documents#show'
      resources :allergens, only: [:index, :create, :destroy]
      # Search routes
      get 'search', to: 'search#index'

      # Support team moderation (country-level)
      scope :support do
        # Support tickets
        resources :tickets, controller: 'support_tickets', only: [:index, :show, :update, :create]
        get 'tickets/my', to: 'support_tickets#my'
        get 'reasons', to: 'support_tickets#reasons'
      end
      
      # Authentication routes
      post 'auth/register', to: 'auth#register'
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      
      # User profile management
      get 'users/me', to: 'users#me'
      get 'users/me/push_notification_settings', to: 'users#push_notification_settings'
      patch 'users/me/push_notification_settings', to: 'users#update_push_notification_settings'
      get 'users/:id/share_qr', to: 'users#share_qr'
      get 'users/:id', to: 'users#show'
      patch 'users/me', to: 'users#update'
      post 'users/me/upload_profile_picture', to: 'users#upload_profile_picture'
      post 'users/me/change_email', to: 'users#change_email'
      post 'users/me/change_phone', to: 'users#change_phone'
      post 'users/me/verify_email_change', to: 'users#verify_email_change'
      post 'users/me/verify_phone_change', to: 'users#verify_phone_change'
      post 'users/me/unlink_email', to: 'users#unlink_email'
      post 'users/me/unlink_phone', to: 'users#unlink_phone'
      post 'users/me/deactivate', to: 'users#deactivate'
      post 'users/me/reactivate', to: 'users#reactivate'
      
      # Notifications
      resources :notifications, only: [:index, :show, :destroy] do
        member do
          post 'read', to: 'notifications#mark_read'
          post 'unread', to: 'notifications#mark_unread'
        end
        collection do
          get 'unread_count', to: 'notifications#unread_count'
          post 'mark_all_read', to: 'notifications#mark_all_read'
          delete 'clear_all', to: 'notifications#clear_all'
        end
      end
      
      # OTP Authentication routes
      post 'auth/send_otp', to: 'auth#send_otp'
      post 'auth/verify_otp', to: 'auth#verify_otp'
      post 'auth/complete_registration', to: 'auth#complete_registration'
      
      # Device and Biometric Authentication routes
      post 'auth/check_device', to: 'auth#check_device'
      post 'auth/register_device', to: 'auth#register_device'
      post 'auth/update_fcm_token', to: 'auth#update_fcm_token'
      post 'auth/authenticate_biometric', to: 'auth#authenticate_biometric'
      get 'auth/devices', to: 'auth#list_devices'
      delete 'auth/devices/:id', to: 'auth#revoke_device'
      patch 'auth/devices/:id/enable_biometric', to: 'auth#enable_biometric'
      patch 'auth/devices/:id/disable_biometric', to: 'auth#disable_biometric'
      
      # PIN Authentication routes
      post 'auth/authenticate_pin', to: 'auth#authenticate_pin'
      post 'auth/devices/:id/setup_pin', to: 'auth#setup_pin'
      patch 'auth/devices/:id/enable_pin', to: 'auth#enable_pin'
      patch 'auth/devices/:id/disable_pin', to: 'auth#disable_pin'
      
      # Password setup
      post 'auth/setup_password', to: 'auth#setup_password'

      # Location management
      get 'location', to: 'locations#show'
      post 'location/device', to: 'locations#device'
      post 'location/manual', to: 'locations#manual'
      post 'location/reset', to: 'locations#reset'

      resources :categories_groups, only: [:index]

      # Map view - venues and events
      get 'maps', to: 'maps#index'
      get 'maps/filter_options', to: 'maps#filter_options'

      # Properties (real-estate)
      resources :properties, except: [:new, :edit] do
        member do
          post 'submit', to: 'properties#submit'
          post 'approve', to: 'properties#approve'
          post 'reject', to: 'properties#reject'
          post 'images', to: 'properties#upload_images'
          delete 'images/:image_id', to: 'properties#remove_image'
          post 'video', to: 'properties#upload_video'
          delete 'video', to: 'properties#remove_video'
        end
      end
      
      # Event Reporting (Admin and User)
      
      # Wallet and Payment Management
      resources :wallets, only: [:index, :show] do
        collection do
          get 'by_currency/:currency', to: 'wallets#by_currency'
        end
      end
      
      resources :payment_transactions, only: [:index, :show] do
        member do
          post 'refund', to: 'payment_transactions#refund'
        end
      end
      
      # Payment operations
      post 'payments/deposit', to: 'payments#deposit'
      post 'payments/withdraw', to: 'payments#withdraw'
      post 'payments/pay', to: 'payments#pay'
      post 'payments/create_intent', to: 'payments#create_intent'
      post 'payments/confirm_intent', to: 'payments#confirm_intent'
      get 'payments/intent/:payment_intent_id', to: 'payments#intent_status'
      
      # Crypto wallet management
      resources :crypto_wallets, only: [:index, :show, :create, :update, :destroy]
      
      # Payment methods management
      resources :payment_methods, only: [:index, :show, :create, :update, :destroy] do
        member do
          post 'set_default', to: 'payment_methods#set_default'
        end
      end
      
      # Webhooks (no authentication required)
      # NOTE: Do not use `namespace :webhooks` here; it would look for Api::V1::Webhooks::* controllers.
      post 'webhooks/stripe', to: 'webhooks#stripe'
      post 'webhooks/paypal', to: 'webhooks#paypal'
      post 'webhooks/crypto', to: 'webhooks#crypto'
      
      # Admin endpoints
      namespace :admin do
        get 'legal_documents', to: 'legal_documents#index'
        post 'legal_documents/:kind/upload', to: 'legal_documents#upload'

        resources :payment_providers, only: [:index, :show, :create, :update, :destroy] do
          member do
            post 'activate', to: 'payment_providers#activate'
            post 'deactivate', to: 'payment_providers#deactivate'
          end
        end
      end
    end
  end

  # ActionCable mount
  mount ActionCable.server => '/cable'

  # WebView routes (outside API namespace - returns HTML, not JSON)
  get 'webviews/venues/:venue_id/floor_plans/:id', to: 'webviews#floor_plan', as: :floor_plan_webview
  get 'webviews/venues/:venue_id/floor_plans/:id/select', to: 'webviews#floor_plan_select', as: :floor_plan_select_webview

  # Root route
  root to: proc { [200, {}, ['Vibes API - v1.0']] }
end
