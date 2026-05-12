module Api
  module V1
    class UsersController < ApplicationController
      before_action :require_authentication!, except: [:share_qr]
      before_action :set_user, only: [:show]
      before_action :set_user_for_qr, only: [:share_qr]

      PUSH_NOTIFICATION_SETTINGS_DEFAULTS = {
        'interactions' => {
          'like' => true,
          'comments' => true,
          'new_followers' => true,
          'mentions_and_tags' => true
        },
        'rsvp_and_booking' => {
          'reminder_24h' => true,
          'reminder_1h' => true,
          'booking_cancellation_confirmation' => true,
          'event_cancellation_notification' => true,
          'event_details_update' => true,
          'vibecheck_feedback' => true
        },
        'new_post_events' => {
          'venue_new_events' => true,
          'venue_new_reels' => true,
          'artist_new_songs' => true,
          'artist_new_events' => true
        },
        'chat' => {
          'direct_messages' => true
        }
      }.freeze
      
      # GET /api/v1/users/:id
      def show
        api_success(
          data: { user: user_profile_response(@user) },
          status: :ok
        )
      end
      
      # GET /api/v1/users/me
      def me
        data = { user: user_response(current_user) }
        api_success(data: data, status: :ok)
      end
      
      # PATCH /api/v1/users/me
      def update
        # Only allow updating name, username, date_of_birth, profile_picture_url directly
        # Email and phone require separate OTP verification endpoints
        update_params = user_params.except(:email, :phone)
        
        if current_user.update(update_params)
          api_success(
            data: { user: user_response(current_user) },
            message: 'Profile updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: current_user.errors.full_messages)
        end
      end

      # GET /api/v1/users/me/push_notification_settings
      def push_notification_settings
        settings = merged_push_notification_settings(current_user)
        api_success(data: { push_notification_settings: settings }, status: :ok)
      end

      # PATCH /api/v1/users/me/push_notification_settings
      #
      # Body:
      # {
      #   "push_notification_settings": {
      #     "interactions": { "like": false }
      #   }
      # }
      def update_push_notification_settings
        incoming = extract_push_notification_settings_param
        unless incoming
          api_error(message: 'push_notification_settings is required', status: :bad_request)
          return
        end

        sanitized = sanitize_push_notification_settings(incoming)
        if sanitized[:error]
          api_error(message: sanitized[:error], status: :bad_request)
          return
        end

        prefs = (current_user.preferences.presence || {}).deep_dup
        existing = prefs['push_notification_settings'].is_a?(Hash) ? prefs['push_notification_settings'] : {}
        updated = existing.deep_merge(sanitized[:settings])
        prefs['push_notification_settings'] = updated

        if current_user.update(preferences: prefs)
          api_success(
            data: { push_notification_settings: merged_push_notification_settings(current_user) },
            message: 'Push notification settings updated',
            status: :ok
          )
        else
          api_validation_error(errors: current_user.errors.full_messages)
        end
      end
      
      # POST /api/v1/users/me/upload_profile_picture
      def upload_profile_picture
        profile_picture = params[:profile_picture] || params[:image] || params[:file]
        
        if profile_picture.blank?
          api_error(message: 'Profile picture file is required', status: :bad_request)
          return
        end
        
        # Validate file type
        unless profile_picture.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
          api_error(message: 'Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed', status: :bad_request)
          return
        end
        
        # Validate file size (max 5MB)
        if profile_picture.size > 5.megabytes
          api_error(message: 'File size too large. Maximum size is 5MB', status: :bad_request)
          return
        end
        
        # Attach the file
        current_user.profile_picture.attach(profile_picture)
        
        if current_user.profile_picture.attached?
          picture_url = attachment_url(current_user.profile_picture)

          api_success(
            data: { 
              user: user_response(current_user),
              profile_picture_url: picture_url,
              avatar_url: picture_url
            },
            message: 'Profile picture uploaded successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to upload profile picture', status: :unprocessable_entity)
        end
      end
      
      # POST /api/v1/users/me/change_email
      def change_email
        new_email = params[:email]&.downcase&.strip
        
        if new_email.blank? || !new_email.match?(URI::MailTo::EMAIL_REGEXP)
          api_error(message: 'Invalid email address', status: :bad_request)
          return
        end
        
        # Check if email is already taken
        if User.exists?(email: new_email) && User.find_by(email: new_email).id != current_user.id
          api_error(message: 'Email is already taken', status: :bad_request)
          return
        end
        
        # Check if same as current email
        if new_email == current_user.email
          api_error(message: 'New email must be different from current email', status: :bad_request)
          return
        end
        
        # Send OTP to new email
        otp = Otp.create_for_email(new_email)
        if otp.persisted?
          # Create verification token with user_id, pending_email, and otp_id
          token = JsonWebToken.encode(
            user_id: current_user.id,
            pending_email: new_email,
            otp_id: otp.id,
            exp: 15.minutes.from_now.to_i
          )
          
          # Send OTP via email
          EmailService.send_otp(new_email, otp.code) rescue nil
          
          api_success(
            data: {
              verification_token: token,
              email: new_email,
              otp: otp.code, # TODO: Remove this from the response later (for testing only)
              expires_in: "#{Otp::OTP_EXPIRY_MINUTES} minutes",
              message: 'OTP sent to new email. Use verify_email_change endpoint to complete.'
            },
            message: 'OTP sent to new email address',
            status: :ok
          )
        else
          api_validation_error(errors: otp.errors.full_messages)
        end
      end
      
      # POST /api/v1/users/me/change_phone
      def change_phone
        new_phone = normalize_phone(params[:phone])
        
        if new_phone.blank? || new_phone.length < 10
          api_error(message: 'Invalid phone number', status: :bad_request)
          return
        end
        
        # Check if phone is already taken
        if User.exists?(phone: new_phone) && User.find_by(phone: new_phone).id != current_user.id
          api_error(message: 'Phone number is already taken', status: :bad_request)
          return
        end
        
        # Check if same as current phone
        if new_phone == current_user.phone
          api_error(message: 'New phone must be different from current phone', status: :bad_request)
          return
        end
        
        # Send OTP to new phone
        otp = Otp.create_for_phone(new_phone)
        if otp.persisted?
          # Create verification token with user_id, pending_phone, and otp_id
          token = JsonWebToken.encode(
            user_id: current_user.id,
            pending_phone: new_phone,
            otp_id: otp.id,
            exp: 15.minutes.from_now.to_i
          )
          
          # Send OTP via SMS
          SmsService.send_otp(new_phone, otp.code) rescue nil
          
          api_success(
            data: {
              verification_token: token,
              phone: new_phone,
              otp: otp.code, # TODO: Remove this from the response later (for testing only)
              expires_in: "#{Otp::OTP_EXPIRY_MINUTES} minutes",
              message: 'OTP sent to new phone. Use verify_phone_change endpoint to complete.'
            },
            message: 'OTP sent to new phone number',
            status: :ok
          )
        else
          api_validation_error(errors: otp.errors.full_messages)
        end
      end
      
      # POST /api/v1/users/me/deactivate
      def deactivate
        reason = params[:reason]
        additional_feedback = params[:additional_feedback]
        
        begin
          current_user.deactivate!(reason: reason, additional_feedback: additional_feedback)
          
          api_success(
            message: 'Account deactivated successfully',
            data: {
              deactivation: {
                reason: current_user.active_deactivation&.human_readable_reason,
                deactivated_at: current_user.active_deactivation&.deactivated_at
              }
            },
            status: :ok
          )
        rescue ActiveRecord::RecordInvalid => e
          api_validation_error(errors: e.record.errors.full_messages)
        rescue => e
          api_error(message: e.message, status: :unprocessable_entity)
        end
      end
      
      # POST /api/v1/users/me/reactivate (Admin only or support feature)
      def reactivate
        # This could be admin-only or available to users after certain conditions
        reactivated_by = params[:reactivated_by] || 'user'
        notes = params[:notes]
        
        unless current_user.status_disabled?
          api_error(message: 'Account is not deactivated', status: :bad_request)
          return
        end
        
        begin
          current_user.reactivate!(reactivated_by: reactivated_by, notes: notes)
          
          api_success(
            message: 'Account reactivated successfully',
            data: { user: user_response(current_user) },
            status: :ok
          )
        rescue => e
          api_error(message: e.message, status: :unprocessable_entity)
        end
      end
      
      # POST /api/v1/users/me/unlink_email
      def unlink_email
        # Check if user has a phone number before allowing email unlinking
        if current_user.phone.blank?
          api_error(
            message: 'Cannot unlink email. You must have a phone number linked to your account first.',
            status: :bad_request
          )
          return
        end
        
        # Check if email exists
        if current_user.email.blank?
          api_error(
            message: 'No email address is linked to your account',
            status: :bad_request
          )
          return
        end
        
        # Unlink the email
        if current_user.update(email: nil)
          api_success(
            data: { user: user_response(current_user) },
            message: 'Email address unlinked successfully',
            status: :ok
          )
        else
          api_validation_error(errors: current_user.errors.full_messages)
        end
      end
      
      # POST /api/v1/users/me/unlink_phone
      def unlink_phone
        # Check if user has an email before allowing phone unlinking
        if current_user.email.blank?
          api_error(
            message: 'Cannot unlink phone. You must have an email address linked to your account first.',
            status: :bad_request
          )
          return
        end
        
        # Check if phone exists
        if current_user.phone.blank?
          api_error(
            message: 'No phone number is linked to your account',
            status: :bad_request
          )
          return
        end
        
        # Unlink the phone
        if current_user.update(phone: nil)
          api_success(
            data: { user: user_response(current_user) },
            message: 'Phone number unlinked successfully',
            status: :ok
          )
        else
          api_validation_error(errors: current_user.errors.full_messages)
        end
      end
      
      # POST /api/v1/users/me/verify_email_change
      def verify_email_change
        verification_token = params[:verification_token]
        code = params[:otp_code]
        
        if verification_token.blank? || code.blank?
          api_error(message: 'Verification token and OTP code are required', status: :bad_request)
          return
        end
        
        begin
          decoded = JsonWebToken.decode(verification_token)
          user_id = decoded[:user_id]
          pending_email = decoded[:pending_email]
          otp_id = decoded[:otp_id]
          
          unless user_id == current_user.id
            api_error(message: 'Invalid verification token', status: :bad_request)
            return
          end
          
          otp = Otp.find_by(id: otp_id)
          unless otp
            api_error(message: 'Invalid verification token', status: :bad_request)
            return
          end
          
          if otp.code != code
            otp.increment_attempts!
            remaining_attempts = Otp::MAX_ATTEMPTS - otp.attempts
            api_error(
              message: 'Invalid OTP code',
              data: { remaining_attempts: remaining_attempts },
              status: :bad_request
            )
            return
          end
          
          # Verify OTP and update email
          otp.mark_verified!
          
          if current_user.update(email: pending_email)
            api_success(
              data: { user: user_response(current_user) },
              message: 'Email updated successfully',
              status: :ok
            )
          else
            api_validation_error(errors: current_user.errors.full_messages)
          end
        rescue => e
          api_error(message: 'Invalid or expired verification token', status: :bad_request)
        end
      end
      
      # POST /api/v1/users/me/verify_phone_change
      def verify_phone_change
        verification_token = params[:verification_token]
        code = params[:otp_code]
        
        if verification_token.blank? || code.blank?
          api_error(message: 'Verification token and OTP code are required', status: :bad_request)
          return
        end
        
        begin
          decoded = JsonWebToken.decode(verification_token)
          user_id = decoded[:user_id]
          pending_phone = decoded[:pending_phone]
          otp_id = decoded[:otp_id]
          
          unless user_id == current_user.id
            api_error(message: 'Invalid verification token', status: :bad_request)
            return
          end
          
          otp = Otp.find_by(id: otp_id)
          unless otp
            api_error(message: 'Invalid verification token', status: :bad_request)
            return
          end
          
          if otp.code != code
            otp.increment_attempts!
            remaining_attempts = Otp::MAX_ATTEMPTS - otp.attempts
            api_error(
              message: 'Invalid OTP code',
              data: { remaining_attempts: remaining_attempts },
              status: :bad_request
            )
            return
          end
          
          # Verify OTP and update phone
          otp.mark_verified!
          
          if current_user.update(phone: pending_phone)
            api_success(
              data: { user: user_response(current_user) },
              message: 'Phone number updated successfully',
              status: :ok
            )
          else
            api_validation_error(errors: current_user.errors.full_messages)
          end
        rescue => e
          api_error(message: 'Invalid or expired verification token', status: :bad_request)
        end
      end
      
      # GET /api/v1/users/search
      def search
        query = params[:q]&.strip
        if query.blank?
          api_error(message: 'Search query is required', status: :bad_request)
          return
        end
        
        users = User.active
                   .where("name ILIKE ? OR username ILIKE ?", "%#{query}%", "%#{query}%")
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = users.count
        users = users.limit(limit).offset(offset)
        
        api_success(
          data: {
            users: users.map { |user| user_basic_response(user) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          },
          status: :ok
        )
      end
      
      # GET /api/v1/users/:id/share_qr
      def share_qr
        require 'rqrcode'
        
        # Generate QR code for user profile with type and id embedded
        user_url = "vibes://users/#{@user.id}"
        qr_data = {
          type: "User",
          id: @user.id,
          url: user_url
        }.to_json
        qr = RQRCode::QRCode.new(qr_data)
        
        # Get size parameter (default: 300)
        size = params[:size].to_i
        size = 300 if size <= 0 || size > 1000 # Limit between 1 and 1000
        
        # Convert to PNG
        png = qr.as_png(
          bit_depth: 1,
          border_modules: 4,
          color_mode: ChunkyPNG::COLOR_GRAYSCALE,
          color: 'black',
          file: nil,
          fill: 'white',
          module_px_size: 6,
          resize_exactly_to: false,
          resize_gte_to: false,
          size: size
        )
        
        # If format=image, return PNG image directly
        if params[:format] == 'image'
          send_data png.to_s, 
                    type: 'image/png', 
                    disposition: 'inline',
                    filename: "user_#{@user.id}_qr.png"
          return
        end
        
        # Otherwise, return JSON with base64 encoded QR code
        api_success(
          data: {
            qr_code: Base64.strict_encode64(png.to_s),
            qr_image_url: "#{request.base_url}/api/v1/users/#{@user.id}/share_qr?format=image&size=#{size}",
            user_url: user_url,
            type: "User",
            user: user_basic_response(@user)
          },
          status: :ok
        )
      end
      
      private

      def merged_push_notification_settings(user)
        prefs = user.preferences.is_a?(Hash) ? user.preferences : {}
        existing = prefs['push_notification_settings'].is_a?(Hash) ? prefs['push_notification_settings'] : {}
        # Ensure every key exists by applying defaults, but keep user's overrides
        PUSH_NOTIFICATION_SETTINGS_DEFAULTS.deep_merge(existing)
      end

      def extract_push_notification_settings_param
        raw = params[:push_notification_settings] || params.dig(:user, :push_notification_settings)
        return nil if raw.nil?
        raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw
      end

      # Returns { settings: Hash } or { error: String }
      def sanitize_push_notification_settings(incoming)
        unless incoming.is_a?(Hash)
          return { error: 'push_notification_settings must be an object' }
        end

        allowed = PUSH_NOTIFICATION_SETTINGS_DEFAULTS
        sanitized = {}

        incoming.each do |group_key, group_val|
          group_key_s = group_key.to_s
          unless allowed.key?(group_key_s)
            return { error: "Unknown settings group: #{group_key_s}" }
          end
          unless group_val.is_a?(Hash)
            return { error: "#{group_key_s} must be an object" }
          end

          sanitized[group_key_s] ||= {}
          group_val.each do |setting_key, setting_val|
            setting_key_s = setting_key.to_s
            unless allowed[group_key_s].key?(setting_key_s)
              return { error: "Unknown setting: #{group_key_s}.#{setting_key_s}" }
            end
            unless setting_val == true || setting_val == false
              return { error: "#{group_key_s}.#{setting_key_s} must be boolean" }
            end
            sanitized[group_key_s][setting_key_s] = setting_val
          end
        end

        { settings: sanitized }
      end
      
      def set_user
        @user = User.find_by(id: params[:id])
        unless @user
          api_error(message: 'User not found', status: :not_found)
          return
        end
      end
      
      def set_user_for_qr
        user_id = params[:id] || params[:user_id]
        @user = User.find_by(id: user_id)
        unless @user
          api_error(message: 'User not found', status: :not_found)
          return
        end
      end
      
      def user_params
        params.require(:user).permit(:name, :username, :date_of_birth, :email, :phone, :bio, :description, :address)
      end

      def normalize_phone(phone)
        return nil if phone.blank?
        phone.gsub(/\D/, '')
      end
      
      def user_response(user)
        avatar = attachment_url(user.profile_picture) || user.profile_picture_url.presence || default_avatar_url

        {
          id: user.id,
          email: user.email,
          phone: user.phone,
          username: user.username,
          name: user.name,
          date_of_birth: user.date_of_birth,
          role: user.role,
          status: user.status,
          avatar_url: avatar,
          profile_picture_url: avatar,
          bio: user.bio,
          description: user.description,
          address: user.address,
          preferences: user.preferences,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end
      
      
      def user_profile_response(user)
        avatar = attachment_url(user.profile_picture) || user.profile_picture_url.presence || default_avatar_url

        {
          id: user.id,
          username: user.username,
          name: user.name,
          role: user.role,
          avatar_url: avatar,
          profile_picture_url: avatar,
          bio: user.bio,
          date_of_birth: user.date_of_birth,
          stats: {
            properties_count: Property.where(owner_id: user.id).count,
            favorites_count: user.favorites.count
          },
          is_me: user == current_user,
          created_at: user.created_at
        }
      end
      
      
      def user_basic_response(user)
        avatar = attachment_url(user.profile_picture) || user.profile_picture_url.presence || default_avatar_url

        {
          id: user.id,
          username: user.username,
          name: user.name,
          role: user.role,
          avatar_url: avatar
        }
      end
    end
  end
end

