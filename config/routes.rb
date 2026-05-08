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
      get 'promo_codes/validate', to: 'promo_codes#validate'
      resources :promo_codes, only: [:index, :create, :update, :destroy]
      # Search routes
      get 'search', to: 'search#index'
      get 'venue_pr/search', to: 'venue_pr#search'

      # Event tags (default, country-wise, trending)
      get 'event_tags', to: 'event_tags#index'

      # Support team moderation (country-level)
      scope :support do
        # Moderation
        scope controller: 'support_moderation' do
          post 'events/:id/remove', action: :remove_event
          post 'events/:event_id/posts/:id/remove', action: :remove_post
        end

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
      get 'users/search', to: 'users#search'
      get 'users/me', to: 'users#me'
      get 'users/me/push_notification_settings', to: 'users#push_notification_settings'
      patch 'users/me/push_notification_settings', to: 'users#update_push_notification_settings'
      get 'users/me/pr_venues', to: 'venue_pr#my_pr_venues'
      get 'users/me/pr/events', to: 'venue_pr#my_pr_events'
      get 'users/me/tickets', to: 'ticket_entitlements#my_tickets'
      get 'users/:user_id/pr_venues', to: 'venue_pr#pr_venues'
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
      
      # Follow/Following
      resources :users, only: [] do
        post 'follow', to: 'follows#follow'
        delete 'follow', to: 'follows#unfollow'
        get 'follow/check', to: 'follows#check_follow'
      end
      get 'users/me/following', to: 'follows#following'
      get 'users/me/followers', to: 'follows#followers'
      
      # Follow Requests (request/accept/reject flow)
      get 'users/me/follow_requests/received', to: 'follow_requests#received'
      get 'users/me/follow_requests/sent', to: 'follow_requests#sent'
      post 'users/me/follow_requests/:id/accept', to: 'follow_requests#accept'
      post 'users/me/follow_requests/:id/reject', to: 'follow_requests#reject'
      post 'users/me/follow_requests/:id/cancel', to: 'follow_requests#cancel'
      
      # Block/Unblock Users
      resources :users, only: [] do
        post 'block', to: 'user_blocks#block'
        delete 'block', to: 'user_blocks#unblock'
        get 'block/check', to: 'user_blocks#check_block'
      end
      get 'users/me/blocked', to: 'user_blocks#my_blocked'
      
      # Collaborators search (venues & brands for events)
      get 'collaborators/search', to: 'collaborators#search'
      
      # Moments / Stories (image or 30s max video)
      post 'moments/stories', to: 'moments#stories'
      post 'moments/stories/dual_cam', to: 'moments#dual_cam_story'
      post 'moments/stories/immersive', to: 'moments#immersive_story'
      get  'moments/my_stories', to: 'moments#my_stories'
      get  'moments/stories', to: 'moments#stories_feed'
      get  'moments/:id/thumbnail', to: 'moments#thumbnail', as: :moment_thumbnail
      get  'moments/:id/download', to: 'moments#download', as: :moment_download
      get    'moments/:id', to: 'moments#show'
      patch  'moments/:id', to: 'moments#update'
      delete 'moments/:id', to: 'moments#destroy'
      
      # Artists (users with artist role)
      resources :artists, only: [:index, :show] do
        member do
          get 'events', to: 'artists#events'
          get 'categories', to: 'artists#categories'
        end
      end
      
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

      scope :artist do
        get 'categories', to: 'artist_categories#index'
        put 'categories', to: 'artist_categories#replace'
        post 'categories/add', to: 'artist_categories#add'
        post 'categories/remove', to: 'artist_categories#remove'
      end
      
      # Venue management
      get 'venues/my_followed', to: 'venues#my_followed'
      resources :venues, except: [:edit] do
        member do
          post 'upload_image', to: 'venues#upload_image'
          get 'share_qr', to: 'venues#share_qr'
          get 'pr', to: 'venue_pr#show'
          post 'pr', to: 'venue_pr#create'
          post 'pr/scan_qr', to: 'venue_pr#scan_qr'
          post 'pr/stop_partnership', to: 'venue_pr#stop_partnership'
        end
        
        # Venue ratings
        resources :ratings, except: [:edit]
        get 'ratings/my_rating', to: 'ratings#my_rating'
        
        # Venue RSVP
        post 'rsvp', to: 'venues#rsvp'
        delete 'rsvp', to: 'venues#remove_rsvp'
        get 'rsvp/check', to: 'venues#check_rsvp'
        get 'rsvps', to: 'venues#list_rsvps'
        
        # Venue following
        post 'follow', to: 'venues#follow'
        delete 'follow', to: 'venues#unfollow'
        get 'follow/check', to: 'venues#check_follow'
        
        # Venue categories management (replace only; create/update venue can set category_ids)
        get 'categories', to: 'venues#venue_categories'
        put 'categories', to: 'venues#replace_venue_categories'
        
        # Venue menus (food/bar)
        post 'menus/:menu_id/categories/reorder', to: 'venue_menus#reorder_categories'
        resources :menus, controller: 'venue_menus', except: [:edit] do
          member do
            post 'image', to: 'venue_menus#upload_menu_image'
            delete 'image', to: 'venue_menus#remove_menu_image'
          end
          post 'categories', to: 'venue_menus#create_category'
          get 'categories/:id', to: 'venue_menus#show_category'
          patch 'categories/:id', to: 'venue_menus#update_category'
          delete 'categories/:id', to: 'venue_menus#delete_category'
          post 'categories/:id/image', to: 'venue_menus#upload_category_image'
          delete 'categories/:id/image', to: 'venue_menus#remove_category_image'
          post 'items', to: 'venue_menus#create_item'
          get 'items/:id', to: 'venue_menus#show_item'
          patch 'items/:id', to: 'venue_menus#update_item'
          delete 'items/:id', to: 'venue_menus#delete_item'
          post 'items/:id/image', to: 'venue_menus#upload_item_image'
          delete 'items/:id/image', to: 'venue_menus#remove_item_image'
        end
        
        # Venue events
        get 'events', to: 'events#venue_events'
        get 'events/last_address', to: 'events#last_address'
        resources :events, only: [:create]
        
        # Floor plan management
        resources :floor_plans, except: [:edit] do
          member do
            post 'activate', to: 'floor_plans#activate'
            post 'duplicate', to: 'floor_plans#duplicate'
            get 'canvas', to: 'floor_plans#canvas'
          end
          
          # Floor plan zones
          post 'zones', to: 'floor_plans#create_zone'
          patch 'zones/:zone_id', to: 'floor_plans#update_zone'
          delete 'zones/:zone_id', to: 'floor_plans#destroy_zone'
          
          # Floor plan tables
          post 'zones/:zone_id/tables', to: 'floor_plans#create_table'
          patch 'tables/:table_id', to: 'floor_plans#update_table'
          delete 'tables/:table_id', to: 'floor_plans#destroy_table'
          
          # Floor plan elements
          post 'elements', to: 'floor_plans#create_element'
          patch 'elements/:element_id', to: 'floor_plans#update_element'
          delete 'elements/:element_id', to: 'floor_plans#destroy_element'
        end
      end
      
      # Venue-type categories (restaurant, pub, cinema, etc.) - list without venue context
      get 'venue_categories', to: 'venues#list_venue_categories'
      
      # Event categories (must be before resources :events to avoid route conflicts)
      get 'events/categories', to: 'events#categories'
      get 'events/categories/:category/events', to: 'events#events_by_category'
      get 'events/report_reasons', to: 'events#report_reasons'

      # Ticket types (tiered pricing for attendance_mode=tickets; max 10 per event)
      get 'events/:event_id/ticket_types', to: 'event_ticket_types#index'
      post 'events/:event_id/ticket_types', to: 'event_ticket_types#create'
      put 'events/:event_id/ticket_types', to: 'event_ticket_types#replace'
      patch 'events/:event_id/ticket_types/:id', to: 'event_ticket_types#update'
      delete 'events/:event_id/ticket_types/:id', to: 'event_ticket_types#destroy'

      get 'bookings/:booking_id/tickets', to: 'ticket_entitlements#index'
      get 'ticket_entitlements/:id/qr', to: 'ticket_entitlements#qr'
      post 'ticket_entitlements/:id/invite', to: 'ticket_entitlements#invite'
      post 'ticket_entitlements/claim', to: 'ticket_entitlements#claim'
      
      # Boost options (must be before resources :events to avoid route conflicts)
      get 'events/boost/performance_goals', to: 'events#boost_performance_goals'
      get 'events/boost/targeting_options', to: 'events#boost_targeting_options'
      
      # Event management
      post 'events', to: 'events#create_global'
      get 'events/by_invite', to: 'events#by_invite'
      resources :events, only: [:index, :show, :update, :destroy] do
        member do
          post 'publish', to: 'events#publish'
          post 'cancel', to: 'events#cancel'
          post 'block', to: 'events#block'
          post 'unblock', to: 'events#unblock'
          get 'share_qr', to: 'events#share_qr'
          get 'pr_chat_users', to: 'events#pr_chat_users'
          post 'regenerate_invite', to: 'events#regenerate_invite'
          post 'photos', to: 'events#upload_photos'
          delete 'photos/:photo_id', to: 'events#remove_photo'
          
          # Event boost routes
          get 'boosts', to: 'events#list_boosts'
          post 'boost', to: 'events#create_boost'
          
          # Event reviews routes
          get 'reviews/my_review', to: 'event_reviews#my_review'
        end
        
        # Event reviews nested routes
        resources :reviews, controller: 'event_reviews', only: [:index, :create, :show, :update, :destroy] do
          get 'boost/:boost_id', to: 'events#show_boost'
          patch 'boost/:boost_id', to: 'events#update_boost'
          delete 'boost/:boost_id', to: 'events#cancel_boost'
          post 'boost/:boost_id/submit', to: 'events#submit_boost_for_review'
          post 'boost/:boost_id/pause', to: 'events#pause_boost'
          post 'boost/:boost_id/resume', to: 'events#resume_boost'
          
          # Event reviews routes
          get 'reviews/my_review', to: 'event_reviews#my_review'
        end
        
        # Event reviews nested routes
        resources :reviews, controller: 'event_reviews', only: [:index, :create, :show, :update, :destroy]
        
        # Event artists
        resources :artists, controller: 'event_artists', only: [:index, :show, :create, :update, :destroy] do
          collection do
            post 'bulk', to: 'event_artists#bulk_add'
            delete 'bulk', to: 'event_artists#bulk_remove'
          end
          member do
            post 'cancel', to: 'event_artists#cancel'
            post 'confirm', to: 'event_artists#confirm'
          end
        end
        
        # Event bookings
        resources :bookings, only: [:index, :create]
        get 'bookings/my_booking', to: 'bookings#my_booking'
        get 'bookings/occupied_tables', to: 'bookings#occupied_tables'
        
        # Event menus (food/bar)
        get 'menus', to: 'menus#index'
        get 'menus/:menu_id', to: 'menus#show_menu'
        post 'menus', to: 'menus#create_menu'
        post 'menus/:menu_id/categories', to: 'menus#create_category'
        get 'menus/:menu_id/categories/:id', to: 'menus#show_category'
        patch 'menus/:menu_id/categories/:id', to: 'menus#update_category'
        delete 'menus/:menu_id/categories/:id', to: 'menus#delete_category'
        post 'menus/:menu_id/categories/reorder', to: 'menus#reorder_categories'
        post 'menus/:menu_id/items', to: 'menus#create_item'
        get 'menus/:menu_id/items/:id', to: 'menus#show_item'
        patch 'menus/:menu_id/items/:id', to: 'menus#update_item'
        delete 'menus/:menu_id/items/:id', to: 'menus#delete_item'
        post 'menus/:menu_id/image', to: 'menus#upload_menu_image'
        delete 'menus/:menu_id/image', to: 'menus#remove_menu_image'
        post 'menus/:menu_id/categories/:id/image', to: 'menus#upload_category_image'
        delete 'menus/:menu_id/categories/:id/image', to: 'menus#remove_category_image'
        post 'menus/:menu_id/items/:id/image', to: 'menus#upload_item_image'
        delete 'menus/:menu_id/items/:id/image', to: 'menus#remove_item_image'
        
        # Event orders (food/bar)
        resources :orders, only: [:create]
        get 'orders', to: 'orders#event_orders'
        
        # Waiter calls
        post 'call_waiter', to: 'waiter_calls#create'
        get 'waiter_calls', to: 'waiter_calls#event_calls'
        
        # Event likes
        resources :likes, only: [:index, :create, :destroy] do
          put 'toggle', on: :collection
          patch 'toggle', on: :collection
        end
        get 'likes/check', to: 'likes#check_like'
        
        # Event interests (simple boolean interest - no RSVP status)
        post 'interests/toggle', to: 'events#toggle_interest' # Toggle interest (recommended)
        post 'interests', to: 'events#mark_interest' # Mark interest (legacy)
        delete 'interests', to: 'events#unmark_interest' # Remove interest (legacy)
        get 'interests/check', to: 'events#check_interest'
        get 'interests', to: 'events#list_interests'
        
        # Event RSVP (full RSVP with status yes/no/maybe, guest count, notes)
        post 'rsvp', to: 'events#mark_rsvp'
        post 'rsvp/approve', to: 'events#approve_rsvp'
        delete 'rsvp', to: 'events#unmark_rsvp'
        get 'rsvp/check', to: 'events#check_rsvp'
        get 'rsvp', to: 'events#list_rsvps'
        
        # Event reports
        post 'report', to: 'events#report'
        get 'reports/check', to: 'events#check_report'
        
        # Event category check (legacy single category)
        get 'category/check', to: 'events#check_category'
        
        # Event categories management (multiple categories like artists)
        get 'categories', to: 'events#event_categories'
        put 'categories', to: 'events#replace_event_categories'
        post 'categories/add', to: 'events#add_event_categories'
        post 'categories/remove', to: 'events#remove_event_categories'
        
        # Event custom categories management
        get 'custom_categories', to: 'events#list_custom_categories'
        post 'custom_categories', to: 'events#create_custom_categories'
        patch 'custom_categories/:id', to: 'events#update_custom_category'
        delete 'custom_categories/:id', to: 'events#destroy_custom_category'
        delete 'custom_categories', to: 'events#destroy_multiple_custom_categories'
        
        # Event posts
        resources :posts, controller: 'event_posts', only: [:index, :show, :create, :update, :destroy] do
          member do
            post 'like', to: 'event_posts#like'
            delete 'like', to: 'event_posts#unlike'
          end
        end
      end
      
      # Venue likes
      resources :venues, only: [] do
        resources :likes, only: [:index, :create, :destroy] do
          put 'toggle', on: :collection
          patch 'toggle', on: :collection
        end
        get 'likes/check', to: 'likes#check_like'
      end
      
      # Bookings (create with event_id in body: POST /bookings)
      post 'bookings', to: 'bookings#create'
      get 'bookings/my_bookings', to: 'bookings#my_bookings'
      resources :bookings, only: [:show, :update] do
        member do
          get 'pr_chat_users', to: 'bookings#pr_chat_users'
          post 'cancel', to: 'bookings#cancel'
          post 'request_cancellation', to: 'bookings#request_cancellation'
          post 'check_in', to: 'bookings#check_in'
          post 'check_out', to: 'bookings#check_out'
          post 'pay', to: 'bookings#pay'
          post 'create_payment_intent', to: 'bookings#create_payment_intent'
          get 'cancellation_info', to: 'bookings#cancellation_info'
          get 'payment_details', to: 'bookings#payment_details'
          get 'share_qr', to: 'bookings#share_qr'
          post 'assign_table', to: 'bookings#assign_table'
          patch 'preorder', to: 'bookings#update_preorder'
          post 'preorder/items', to: 'bookings#add_preorder_item'
          patch 'preorder/items/:item_id', to: 'bookings#update_preorder_item'
          delete 'preorder/items/:item_id', to: 'bookings#remove_preorder_item'
        end
      end
      
      # Orders
      get 'orders/my_orders', to: 'orders#my_orders'
      get 'orders/split_qr/:qr_token/image', to: 'orders#split_qr_image'
      post 'orders/join_split/:qr_token', to: 'orders#join_split_by_qr'
      resources :orders, only: [:show] do
        member do
          post 'cancel', to: 'orders#cancel'
          post 'add_tip', to: 'orders#add_tip'
          post 'split', to: 'orders#create_split'
          get 'splits', to: 'orders#list_splits'
          patch 'splits', to: 'orders#update_splits'
          post 'split_qr', to: 'orders#create_split_qr'
          post 'splits/:split_id/pay', to: 'orders#pay_split'
        end
      end
      
      # Waiter calls
      get 'waiter_calls/my_calls', to: 'waiter_calls#my_calls'
      resources :waiter_calls, only: [:show] do
        member do
          post 'acknowledge', to: 'waiter_calls#acknowledge'
          post 'complete', to: 'waiter_calls#complete'
          post 'cancel', to: 'waiter_calls#cancel'
        end
      end
      
      # Venue Manager Dashboard
      scope :venue_manager do
        get 'my_venues', to: 'venue_manager#my_venues'
        get 'dashboard_summary', to: 'venue_manager#dashboard_summary'
      end
      
      scope 'venues/:venue_id/manager' do
        get 'dashboard', to: 'venue_manager#dashboard'
        get 'dashboard_metrics', to: 'venue_manager#dashboard_metrics'
        get 'analytics', to: 'venue_manager#analytics'
        get 'revenue_report', to: 'venue_manager#revenue_report'
        
        # Staff management
        get 'staff', to: 'venue_manager#staff_list'
        post 'staff', to: 'venue_manager#add_staff'
        patch 'staff/:id', to: 'venue_manager#update_staff'
        delete 'staff/:id', to: 'venue_manager#remove_staff'
        post 'staff/:id/update_location', to: 'venue_manager#update_staff_location'
        
        # Table management
        get 'tables_overview', to: 'venue_manager#tables_overview'
        get 'table/:table_number', to: 'venue_manager#table_details'
        post 'tables/:table_number/assign_booking', to: 'venue_manager#assign_table'

        # Orders tabs (venue manager)
        get 'orders', to: 'venue_manager#orders_tables'
        get 'preorders', to: 'venue_manager#preorders_tables'
        get 'waiting_waiter', to: 'venue_manager#waiting_waiter_tables'
        
        # Live operations
        get 'live_orders', to: 'venue_manager#live_orders'
        post 'orders/:order_id/update_status', to: 'venue_manager#update_order_status'
        get 'active_calls', to: 'venue_manager#active_calls'
        
        # Booking management
        get 'bookings', to: 'venue_manager#venue_bookings'
        get 'bookings/:booking_id', to: 'venue_manager#booking_details'
        post 'bookings/:booking_id/approve', to: 'venue_manager#approve_booking'
        # Some clients mistakenly call this as GET; allow it for backward compatibility.
        # NOTE: This mutates state and is not RESTful; prefer POST.
        get  'bookings/:booking_id/approve', to: 'venue_manager#approve_booking'
        post 'bookings/:booking_id/reject', to: 'venue_manager#reject_booking'
        post 'bookings/:booking_id/block', to: 'venue_manager#block_booking'
        post 'bookings/:booking_id/cancel', to: 'venue_manager#cancel_booking_by_manager'
        post 'bookings/:booking_id/assign_pr', to: 'venue_manager#assign_booking_pr'
        # Some clients mistakenly call this as GET; allow it for backward compatibility.
        get  'bookings/:booking_id/assign_pr', to: 'venue_manager#assign_booking_pr'
        post 'bookings/:booking_id/unassign_pr', to: 'venue_manager#unassign_booking_pr'
        
        # Event participants & cancellations
        get 'events/:event_id/participants', to: 'venue_manager#event_participants'
        get 'events/:event_id/pending_cancellations', to: 'venue_manager#pending_cancellations'
        post 'events/:event_id/bookings/:booking_id/approve_cancellation', to: 'venue_manager#approve_cancellation'
        post 'events/:event_id/bookings/:booking_id/reject_cancellation', to: 'venue_manager#reject_cancellation'
        
        # RSVP management
        get 'events/:event_id/rsvps', to: 'venue_manager#event_rsvps'
        post 'events/:event_id/rsvps/:user_id/approve', to: 'venue_manager#approve_rsvp'
        post 'events/:event_id/rsvps/:user_id/block', to: 'venue_manager#block_rsvp'
        post 'events/:event_id/rsvps/:user_id/cancel', to: 'venue_manager#cancel_rsvp'
        
        # Blocklist
        get 'blocklist/reasons', to: 'venue_manager#blocklist_reasons'
        get 'blocklist', to: 'venue_manager#blocklist'
        post 'blocklist/:user_id', to: 'venue_manager#add_to_blocklist'
        delete 'blocklist/:id', to: 'venue_manager#remove_from_blocklist'
      end
      
      # VibeCheck (Post-event ratings)
      resources :events, only: [] do
        resources :vibe_checks, only: [:index, :create]
      end
      
      get 'vibe_checks/my_checks', to: 'vibe_checks#my_checks'
      resources :vibe_checks, only: [:show, :update, :destroy] do
        member do
          post 'helpful', to: 'vibe_checks#mark_helpful'
        end
      end
      
      # Map view - venues and events
      get 'maps', to: 'maps#index'
      get 'maps/filter_options', to: 'maps#filter_options'
      
      # Event Reporting (Admin and User)
      get 'reporting', to: 'reporting#index'
      get 'reporting/:id', to: 'reporting#show'
      patch 'reporting/:id/review', to: 'reporting#review'
      get 'reporting/my_reports', to: 'reporting#my_reports'
      
      # Group chat messaging (Group communication)
      resources :group_chats, only: [:index, :show, :create, :update, :destroy] do
        member do
          get 'members', to: 'group_chats#list_members'
          get 'available_users', to: 'group_chats#available_users'
          post 'add_member', to: 'group_chats#add_member'
          delete 'remove_member', to: 'group_chats#remove_member'
          post 'leave', to: 'group_chats#leave'
          post 'mute', to: 'group_chats#mute'
          post 'unmute', to: 'group_chats#unmute'
          post 'pin', to: 'group_chats#pin'
          post 'unpin', to: 'group_chats#unpin'
          post 'star', to: 'group_chats#star'
          post 'unstar', to: 'group_chats#unstar'
          post 'archive', to: 'group_chats#archive'
          post 'unarchive', to: 'group_chats#unarchive'
          get 'invite_qr', to: 'group_chats#invite_qr'
          get 'invite_url', to: 'group_chats#invite_url'
          post 'regenerate_invite', to: 'group_chats#regenerate_invite'
        end
        collection do
          post 'join_by_code', to: 'group_chats#join_by_code'
        end
        resources :messages, controller: 'group_chat_messages', only: [:index, :show, :create, :destroy] do
          member do
            patch 'edit', to: 'group_chat_messages#edit'
            post 'forward', to: 'group_chat_messages#forward'
          end
        end
      end
      
      # One-on-one chat messaging
      resources :chats, only: [:index, :show, :create] do
        member do
          post 'block', to: 'chats#block'
          post 'unblock', to: 'chats#unblock'
          post 'mute', to: 'chats#mute'
          post 'unmute', to: 'chats#unmute'
          post 'pin', to: 'chats#pin'
          post 'unpin', to: 'chats#unpin'
          post 'archive', to: 'chats#archive'
          post 'unarchive', to: 'chats#unarchive'
          post 'report', to: 'chats#report'
        end
        resources :messages, controller: 'chat_messages', only: [:index, :show, :create, :destroy] do
          member do
            patch 'edit', to: 'chat_messages#edit'
            post 'forward', to: 'chat_messages#forward'
          end
        end
      end
      
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

  # Legacy/compat routes (non-versioned clients)
  # Some clients POST messages to /chats/:chat_id/messages instead of /api/v1/...
  post 'chats/:chat_id/messages', to: 'api/v1/chat_messages#create'

  # ActionCable mount
  mount ActionCable.server => '/cable'

  # WebView routes (outside API namespace - returns HTML, not JSON)
  get 'webviews/venues/:venue_id/floor_plans/:id', to: 'webviews#floor_plan', as: :floor_plan_webview
  get 'webviews/venues/:venue_id/floor_plans/:id/select', to: 'webviews#floor_plan_select', as: :floor_plan_select_webview

  # Root route
  root to: proc { [200, {}, ['Vibes API - v1.0']] }
end
