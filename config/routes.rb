Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Legal / policy documents (public URLs for in-app display)
      get 'legal_documents', to: 'legal_documents#index'
      get 'legal_documents/:kind', to: 'legal_documents#show'

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

      # Map view - properties only
      get 'maps', to: 'maps#index'
      get 'maps/filter_options', to: 'maps#filter_options'

      # Properties (real-estate)
      resources :properties, except: [:new, :edit] do
        member do
          post 'submit', to: 'properties#submit'
          post 'approve', to: 'properties#approve'
          post 'reject', to: 'properties#reject'
          post 'mark_sold', to: 'properties#mark_sold'
          post 'archive', to: 'properties#archive'
          post 'unarchive', to: 'properties#unarchive'
          post 'images', to: 'properties#upload_images'
          delete 'images/:image_id', to: 'properties#remove_image'
          post 'video', to: 'properties#upload_video'
          delete 'video', to: 'properties#remove_video'
        end
      end

      # Favorites
      get 'favorites', to: 'favorites#index'
      post 'properties/:property_id/favorite', to: 'favorites#create'
      delete 'properties/:property_id/favorite', to: 'favorites#destroy'

      # Viewings (appointments)
      get 'viewings', to: 'property_viewings#index'
      get 'viewings/my', to: 'property_viewings#my'
      get 'viewings/:id', to: 'property_viewings#show'
      patch 'viewings/:id', to: 'property_viewings#update'
      post 'viewings/:id/cancel', to: 'property_viewings#cancel'
      get 'properties/:property_id/viewings', to: 'property_viewings#property_viewings'
      post 'properties/:property_id/viewings', to: 'property_viewings#create'
      
      # Admin endpoints
      namespace :admin do
        get 'legal_documents', to: 'legal_documents#index'
        post 'legal_documents/:kind/upload', to: 'legal_documents#upload'
      end
    end
  end

  # ActionCable mount
  mount ActionCable.server => '/cable'

  # Root route
  root to: proc { [200, {}, ['Vibes API - v1.0']] }
end
