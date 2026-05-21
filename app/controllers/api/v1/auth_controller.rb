module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_request, only: [:register, :login, :send_otp, :verify_otp, :complete_registration, :authenticate_biometric, :authenticate_pin, :check_device, :forgot_password, :verify_reset_otp, :reset_password]

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)
        
        if user.save
          # Generate persistent token (90 days) for Instagram-like login
          token = JsonWebToken.encode_persistent(user_id: user.id)
          
          api_success(
            data: {
              user: user_response(user),
              token: token
            },
            message: 'User created successfully',
            status: :created
          )
        else
          api_validation_error(errors: user.errors.full_messages)
        end
      end

      # POST /api/v1/auth/login
      def login
        identifier = login_params[:username] || login_params[:email] || login_params[:phone]
        
        if identifier.blank?
          api_error(message: 'Username, email, or phone is required', status: :bad_request)
          return
        end

        if login_params[:password].blank?
          api_error(message: 'Password is required', status: :bad_request)
          return
        end

        # Find user by username, email, or phone
        user = if login_params[:username].present?
                 User.find_by(username: login_params[:username])
               elsif login_params[:email].present?
                 User.find_by(email: login_params[:email]&.downcase)
               else
                 User.find_by(phone: normalize_phone(login_params[:phone]))
               end

        if user&.authenticate(login_params[:password])
          if user.status_disabled?
            api_error(message: 'Account is disabled', status: :bad_request)
            return
          end

          # Generate persistent token (90 days) for Instagram-like login
          token = JsonWebToken.encode_persistent(user_id: user.id)
          
          api_success(
            data: {
              user: user_response(user),
              token: token
            },
            message: 'Login successful',
            status: :ok
          )
        else
          api_error(message: 'Invalid credentials', status: :bad_request)
        end
      end

      # POST /api/v1/auth/logout
      def logout
        # With JWT, logout is handled client-side by removing the token
        # Server can optionally maintain a blacklist of tokens (future enhancement)
        api_success(message: 'Logged out successfully', status: :ok)
      end

      # GET /api/v1/auth/me
      def me
        require_authentication!
        return if performed?

        api_success(data: { user: user_response(current_user) }, status: :ok)
      end

      # POST /api/v1/auth/send_otp
      # Just send OTP - don't create user yet
      def send_otp
        phone = normalize_phone(otp_params[:phone]) if otp_params[:phone].present?
        email = otp_params[:email]&.downcase&.strip
        
        # Validate that either phone or email is provided
        if phone.blank? && email.blank?
          api_error(message: 'Either phone or email is required', status: :bad_request)
          return
        end

        # Validate phone format if provided
        if phone.present? && phone.length < 10
          api_error(message: 'Invalid phone number', status: :bad_request)
          return
        end

        # Validate email format if provided
        if email.present? && !email.match?(URI::MailTo::EMAIL_REGEXP)
          api_error(message: 'Invalid email address', status: :bad_request)
          return
        end

        # Determine which identifier to use
        identifier = phone.present? ? phone : email
        identifier_type = phone.present? ? :phone : :email

        # Check rate limiting (max 3 OTP requests per identifier)
        rate_limit_check = Otp.check_rate_limit(identifier, type: identifier_type)
        unless rate_limit_check[:allowed]
          api_error(
            message: rate_limit_check[:message],
            data: {
              reason: rate_limit_check[:reason],
              requests_used: rate_limit_check[:requests_used],
              max_requests: rate_limit_check[:max_requests]
            },
            status: :bad_request
          )
          return
        end

        # Check if user exists
        existing_user = if phone.present?
                          User.find_by(phone: phone)
                        else
                          User.find_by(email: email)
                        end

        # If user exists and is disabled, reject
        if existing_user&.status_disabled?
          api_error(message: 'Account is disabled', status: :bad_request)
          return
        end

        # Create OTP (don't create user yet)
        otp = if phone.present?
                Otp.create_for_phone(phone)
              else
                Otp.create_for_email(email)
              end

        # Send OTP via SMS or Email
        delivery_success = if phone.present?
                             SmsService.send_otp(phone, otp.code)
                           else
                             EmailService.send_otp(email, otp.code)
                           end

        if delivery_success
          response_data = {
            otp: otp.code, # TODO: Remove this from the response later
            expires_in: "#{Otp::OTP_EXPIRY_MINUTES} minutes",
            max_attempts: Otp::MAX_ATTEMPTS,
            requests_remaining: rate_limit_check[:requests_remaining],
            is_new_user: existing_user.nil?
          }
          
          # Add the identifier to the response
          response_data[:phone] = phone if phone.present?
          response_data[:email] = email if email.present?
          
          api_success(data: response_data, message: 'OTP sent successfully', status: :ok)
        else
          delivery_method = phone.present? ? 'SMS' : 'email'
          api_error(message: "Failed to send OTP via #{delivery_method}. Please try again.", status: :bad_request)
        end
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: e.record.errors.full_messages)
      rescue => e
        Rails.logger.error "OTP Send Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to process request', status: :internal_server_error)
      end

      # POST /api/v1/auth/verify_otp
      # Verify OTP - if new user, return flag to complete registration
      def verify_otp
        phone = normalize_phone(verify_otp_params[:phone]) if verify_otp_params[:phone].present?
        email = verify_otp_params[:email]&.downcase&.strip
        code = verify_otp_params[:code]

        # Validate that either phone or email is provided
        if phone.blank? && email.blank?
          api_error(message: 'Either phone or email is required', status: :bad_request)
          return
        end

        if code.blank?
          api_error(message: 'OTP code is required', status: :bad_request)
          return
        end

        # Find the most recent valid OTP for this identifier
        otp = if phone.present?
                Otp.for_phone(phone)
                   .where(verified: false)
                   .order(created_at: :desc)
                   .first
              else
                Otp.for_email(email)
                   .where(verified: false)
                   .order(created_at: :desc)
                   .first
              end

        identifier_type = phone.present? ? "phone number" : "email address"
        
        if otp.nil?
          api_error(message: "No OTP found for this #{identifier_type}", status: :bad_request)
          return
        end

        # Check if expired
        if otp.expired?
          api_error(message: 'OTP has expired. Please request a new one.', status: :bad_request)
          return
        end

        # Check if max attempts reached
        if otp.max_attempts_reached?
          api_error(message: 'Maximum verification attempts reached. Please request a new OTP.', status: :bad_request)
          return
        end

        # Verify OTP code
        if otp.code == code
          # Mark OTP as verified
          otp.mark_verified!
          
          # Find existing user
          user = if phone.present?
                   User.find_by(phone: phone)
                 else
                   User.find_by(email: email)
                 end
          
          if user.nil?
            # NEW USER - Return verification token to complete registration
            verification_token = JsonWebToken.encode(
              verified_phone: phone,
              verified_email: email,
              otp_id: otp.id,
              exp: 15.minutes.from_now.to_i
            )
            
            api_success(
              data: {
                is_new_user: true,
                verification_token: verification_token,
                phone: phone,
                email: email,
                next_step: "Complete registration by providing role and name"
              },
              message: "#{identifier_type.capitalize} verified successfully",
              status: :ok
            )
          else
            # EXISTING USER - Return persistent JWT token (90 days)
            otp.update(user: user) if otp.user_id.nil?
            token = JsonWebToken.encode_persistent(user_id: user.id)
            
            api_success(
              data: {
                is_new_user: false,
                user: user_response(user),
                token: token
              },
              message: "#{identifier_type.capitalize} verified successfully",
              status: :ok
            )
          end
        else
          # Increment failed attempts
          otp.increment_attempts!
          
          remaining_attempts = Otp::MAX_ATTEMPTS - otp.attempts
          
          api_error(
            message: 'Invalid OTP code',
            data: { remaining_attempts: remaining_attempts },
            status: :bad_request
          )
        end
      rescue => e
        Rails.logger.error "OTP Verify Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to verify OTP', status: :internal_server_error)
      end

      # POST /api/v1/auth/complete_registration
      # Complete registration for new users after OTP verification
      def complete_registration
        verification_token = params[:verification_token]
        role = params[:role]
        name = params[:name]

        if verification_token.blank?
          api_error(message: 'Verification token is required', status: :bad_request)
          return
        end

        if role.blank?
          api_error(message: 'Role is required', status: :bad_request)
          return
        end

        unless role.to_s.in?(%w[user owner])
          api_error(message: "Invalid role. Allowed roles: user, owner", status: :bad_request)
          return
        end

        # Decode verification token
        begin
          decoded = JsonWebToken.decode(verification_token)
          phone = decoded[:verified_phone]
          email = decoded[:verified_email]
        rescue => e
          api_error(message: 'Invalid or expired verification token', status: :bad_request)
          return
        end

        # Allow providing additional contact info during registration
        additional_email = params[:email]&.downcase&.strip
        additional_phone = params[:phone]&.strip

        # Check if user already exists — update instead of rejecting
        existing_user = if phone.present?
                          User.find_by(phone: phone)
                        else
                          User.find_by(email: email)
                        end

        if existing_user
          update_attrs = { role: role }
          update_attrs[:name] = name if name.present?
          update_attrs[:description] = params[:description] if params[:description].present?
          update_attrs[:address] = params[:address] if params[:address].present?
          update_attrs[:email] = additional_email if additional_email.present? && existing_user.email.blank?
          update_attrs[:phone] = additional_phone if additional_phone.present? && existing_user.phone.blank?
          update_attrs[:status] = 'active'

          if existing_user.update(update_attrs)
            token = JsonWebToken.encode_persistent(user_id: existing_user.id)

            api_success(
              data: {
                user: user_response(existing_user),
                token: token
              },
              message: 'Registration completed successfully',
              status: :ok
            )
          else
            api_validation_error(errors: existing_user.errors.full_messages)
          end
          return
        end

        # Create new user
        user = User.new(
          phone: phone.presence || additional_phone,
          email: email.presence || additional_email,
          name: name,
          role: role,
          description: params[:description],
          address: params[:address],
          password: SecureRandom.hex(16),
          status: 'active'
        )

        # If verified via phone but also provided email, add it
        if phone.present? && additional_email.present?
          user.email = additional_email
        end

        # If verified via email but also provided phone, add it
        if email.present? && additional_phone.present?
          user.phone = additional_phone
        end

        if user.save
          token = JsonWebToken.encode_persistent(user_id: user.id)

          api_success(
            data: {
              user: user_response(user),
              token: token
            },
            message: 'Registration completed successfully',
            status: :created
          )
        else
          api_validation_error(errors: user.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Complete Registration Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to complete registration', status: :internal_server_error)
      end

      # POST /api/v1/auth/forgot_password
      # Send a password reset OTP to phone or email
      def forgot_password
        phone = normalize_phone(params[:phone]) if params[:phone].present?
        email = params[:email]&.downcase&.strip

        if phone.blank? && email.blank?
          api_error(message: 'Either phone or email is required', status: :bad_request)
          return
        end

        user = if phone.present?
                 User.find_by(phone: phone)
               else
                 User.find_by(email: email)
               end

        # Always respond success to prevent enumeration attacks
        unless user
          api_success(
            data: { sent: false },
            message: 'If an account exists, a reset code has been sent',
            status: :ok
          )
          return
        end

        if user.status_disabled?
          api_error(message: 'Account is disabled', status: :bad_request)
          return
        end

        otp = if phone.present?
                Otp.create_for_phone(phone)
              else
                Otp.create_for_email(email)
              end
        otp.update(user: user)

        delivery_success = if phone.present?
                             SmsService.send_otp(phone, otp.code)
                           else
                             EmailService.send_otp(email, otp.code)
                           end

        if delivery_success
          api_success(
            data: {
              otp: otp.code, # TODO: Remove in production
              phone: phone,
              email: email,
              expires_in: "#{Otp::OTP_EXPIRY_MINUTES} minutes"
            },
            message: 'Password reset OTP sent successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to send OTP', status: :bad_request)
        end
      rescue => e
        Rails.logger.error "Forgot Password Error: #{e.message}"
        api_error(message: 'Failed to process request', status: :internal_server_error)
      end

      # POST /api/v1/auth/verify_reset_otp
      # Verify the reset OTP and return a reset_token to be used with reset_password
      def verify_reset_otp
        phone = normalize_phone(params[:phone]) if params[:phone].present?
        email = params[:email]&.downcase&.strip
        code = params[:code]

        if phone.blank? && email.blank?
          api_error(message: 'Either phone or email is required', status: :bad_request)
          return
        end

        if code.blank?
          api_error(message: 'OTP code is required', status: :bad_request)
          return
        end

        otp = if phone.present?
                Otp.for_phone(phone).where(verified: false).order(created_at: :desc).first
              else
                Otp.for_email(email).where(verified: false).order(created_at: :desc).first
              end

        if otp.nil?
          api_error(message: 'No OTP found. Please request a new reset code.', status: :bad_request)
          return
        end

        if otp.expired?
          api_error(message: 'OTP has expired. Please request a new one.', status: :bad_request)
          return
        end

        if otp.max_attempts_reached?
          api_error(message: 'Maximum attempts reached. Please request a new OTP.', status: :bad_request)
          return
        end

        unless otp.code == code
          otp.increment_attempts!
          remaining = Otp::MAX_ATTEMPTS - otp.attempts
          api_error(
            message: 'Invalid OTP code',
            data: { remaining_attempts: remaining },
            status: :bad_request
          )
          return
        end

        otp.mark_verified!

        user = if phone.present?
                 User.find_by(phone: phone)
               else
                 User.find_by(email: email)
               end

        unless user
          api_error(message: 'User not found', status: :not_found)
          return
        end

        reset_token = JsonWebToken.encode(
          user_id: user.id,
          purpose: 'password_reset',
          otp_id: otp.id,
          exp: 15.minutes.from_now.to_i
        )

        api_success(
          data: {
            reset_token: reset_token,
            expires_in: '15 minutes'
          },
          message: 'OTP verified. Use reset_token to set a new password.',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Verify Reset OTP Error: #{e.message}"
        api_error(message: 'Failed to verify OTP', status: :internal_server_error)
      end

      # POST /api/v1/auth/reset_password
      def reset_password
        reset_token = params[:reset_token]
        password = params[:password]
        password_confirmation = params[:password_confirmation]

        if reset_token.blank?
          api_error(message: 'Reset token is required', status: :bad_request)
          return
        end

        if password.blank?
          api_error(message: 'Password is required', status: :bad_request)
          return
        end

        if password != password_confirmation
          api_error(message: 'Password and confirmation do not match', status: :bad_request)
          return
        end

        if password.length < 8
          api_error(message: 'Password must be at least 8 characters', status: :bad_request)
          return
        end

        begin
          decoded = JsonWebToken.decode(reset_token)
          if decoded[:purpose].to_s != 'password_reset'
            api_error(message: 'Invalid reset token', status: :bad_request)
            return
          end
          user = User.find_by(id: decoded[:user_id])
        rescue => e
          api_error(message: 'Invalid or expired reset token', status: :bad_request)
          return
        end

        unless user
          api_error(message: 'User not found', status: :not_found)
          return
        end

        if user.update(password: password, password_confirmation: password_confirmation)
          token = JsonWebToken.encode_persistent(user_id: user.id)
          api_success(
            data: {
              user: user_response(user),
              token: token
            },
            message: 'Password reset successfully',
            status: :ok
          )
        else
          api_validation_error(errors: user.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Reset Password Error: #{e.message}"
        api_error(message: 'Failed to reset password', status: :internal_server_error)
      end

      # POST /api/v1/auth/register_device
      def register_device
        require_authentication!
        return if performed?
        
        device_params_hash = device_registration_params
        biometric_enabled = device_params_hash[:biometric_enabled] == true || device_params_hash[:biometric_enabled] == 'true'
        fcm_token = params[:fcm_token]

        # Check if device is already registered
        existing_device = current_user.devices.find_by(
          device_uuid: device_params_hash[:device_uuid],
          status: 'active'
        )

        if existing_device
          # Update existing device
          existing_device.update!(
            device_name: device_params_hash[:device_name],
            device_type: device_params_hash[:device_type],
            platform_version: device_params_hash[:platform_version],
            app_version: device_params_hash[:app_version],
            biometric_enabled: biometric_enabled,
            last_used_at: Time.current
          )
          
          # Update FCM token if provided
          existing_device.update_fcm_token!(fcm_token) if fcm_token.present?
          
          api_success(
            data: {
              device: existing_device.device_info,
              biometric_enabled: existing_device.biometric_enabled
            },
            message: 'Device updated successfully',
            status: :ok
          )
        else
          # Register new device
          result = Device.register(
            user: current_user,
            device_params: device_params_hash,
            biometric_enabled: biometric_enabled
          )

          # Set FCM token if provided
          result[:device].update_fcm_token!(fcm_token) if fcm_token.present?

          api_success(
            data: {
              device: result[:device].device_info,
              device_token: result[:token],
              biometric_enabled: result[:device].biometric_enabled
            },
            message: 'Device registered successfully',
            status: :created
          )
        end
      rescue => e
        Rails.logger.error "Device Registration Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        api_error(message: 'Failed to register device', data: { details: e.message }, status: :internal_server_error) unless performed?
      end

      # POST /api/v1/auth/update_fcm_token
      def update_fcm_token
        require_authentication!
        return if performed?
        
        fcm_token = params[:fcm_token]
        device_uuid = params[:device_uuid]

        if fcm_token.blank?
          api_error(message: 'fcm_token is required', status: :bad_request)
          return
        end

        # Find device by UUID if provided, otherwise use first active device
        device = if device_uuid.present?
          current_user.devices.find_by(device_uuid: device_uuid, status: 'active')
        else
          current_user.devices.active.first
        end

        unless device
          api_error(message: 'No active device found', status: :not_found)
          return
        end

        device.update_fcm_token!(fcm_token)

        api_success(
          data: {
            device: device.device_info
          },
          message: 'FCM token updated successfully',
          status: :ok
        )
      rescue => e
        Rails.logger.error "FCM Token Update Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        unless performed?
          api_error(message: 'Failed to update FCM token', data: { details: e.message }, status: :internal_server_error)
        end
      end

      # POST /api/v1/auth/register_fcm_token
      # Register or update FCM token for the current user's device.
      # Body: fcm_token, device_uuid, platform (ios|android), optional device metadata.
      def register_fcm_token
        require_authentication!
        return if performed?

        fcm_token = params[:fcm_token].to_s.strip
        if fcm_token.blank?
          api_error(message: 'fcm_token is required', status: :bad_request)
          return
        end

        device_uuid = params[:device_uuid].presence
        if device_uuid.blank? && current_user.devices.active.none?
          api_error(message: 'device_uuid is required when no active device exists', status: :bad_request)
          return
        end

        device = device_uuid.present? ? current_user.devices.active.find_by(device_uuid: device_uuid) : current_user.devices.active.first
        created = false

        unless device
          platform = params[:platform].to_s.downcase
          unless %w[ios android].include?(platform)
            api_error(message: 'platform is required for new device and must be ios or android', status: :bad_request)
            return
          end

          result = Device.register(
            user: current_user,
            device_params: params.permit(
              :device_uuid,
              :device_name,
              :device_type,
              :platform,
              :platform_version,
              :app_version
            ),
            biometric_enabled: ActiveModel::Type::Boolean.new.cast(params[:biometric_enabled])
          )
          device = result[:device]
          created = true
        end

        device.update!(
          device_name: params[:device_name].presence || device.device_name,
          device_type: params[:device_type].presence || device.device_type,
          platform_version: params[:platform_version].presence || device.platform_version,
          app_version: params[:app_version].presence || device.app_version,
          last_used_at: Time.current
        )
        device.update_fcm_token!(fcm_token)

        api_success(
          data: { device: device.device_info },
          message: created ? 'FCM token registered successfully' : 'FCM token updated successfully',
          status: created ? :created : :ok
        )
      rescue ActiveRecord::RecordNotUnique
        api_error(message: 'device_uuid is already registered to another account', status: :conflict)
      rescue => e
        Rails.logger.error "FCM Token Registration Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        api_error(message: 'Failed to register FCM token', data: { details: e.message }, status: :internal_server_error) unless performed?
      end

      # POST /api/v1/auth/authenticate_biometric
      def authenticate_biometric
        device_token = biometric_auth_params[:device_token]
        device_uuid = biometric_auth_params[:device_uuid]

        if device_token.blank? || device_uuid.blank?
          api_error(message: 'Device token and device UUID are required', status: :bad_request)
          return
        end

        # Find device by token
        device = Device.find_by_token(device_token)

        if device.nil?
          api_error(message: 'Invalid device token', status: :bad_request)
          return
        end

        # Verify device UUID matches
        if device.device_uuid != device_uuid
          api_error(message: 'Device UUID mismatch', status: :bad_request)
          return
        end

        # Check if device can authenticate
        unless device.can_authenticate?
          status_message = device.expired? ? 'Device token has expired' : 'Device is not active'
          api_error(message: status_message, status: :bad_request)
          return
        end

        # Check if biometric is enabled
        unless device.biometric_enabled?
          api_error(message: 'Biometric authentication is not enabled for this device', status: :bad_request)
          return
        end

        # Check if user is disabled
        if device.user.status_disabled?
          api_error(message: 'Account is disabled', status: :bad_request)
          return
        end

        # Update last used timestamp
        device.touch_last_used!

        # Generate persistent JWT token (90 days) for Instagram-like login
        token = JsonWebToken.encode_persistent(user_id: device.user.id)

        api_success(
          data: {
            user: user_response(device.user),
            token: token
          },
          message: 'Biometric authentication successful',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Biometric Auth Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to authenticate', status: :internal_server_error)
      end

      # POST /api/v1/auth/authenticate_pin
      def authenticate_pin
        device_token = pin_auth_params[:device_token]
        device_uuid = pin_auth_params[:device_uuid]
        pin = pin_auth_params[:pin]

        if device_token.blank? || device_uuid.blank?
          api_error(message: 'Device token and device UUID are required', status: :bad_request)
          return
        end

        if pin.blank?
          api_error(message: 'PIN is required', status: :bad_request)
          return
        end

        # Find device by token
        device = Device.find_by_token(device_token)

        if device.nil?
          api_error(message: 'Invalid device token', status: :bad_request)
          return
        end

        # Verify device UUID matches
        if device.device_uuid != device_uuid
          api_error(message: 'Device UUID mismatch', status: :bad_request)
          return
        end

        # Check if device can authenticate
        unless device.can_authenticate?
          status_message = device.expired? ? 'Device token has expired' : 'Device is not active'
          api_error(message: status_message, status: :bad_request)
          return
        end

        # Check if PIN is enabled
        unless device.pin_enabled?
          api_error(message: 'PIN authentication is not enabled for this device', status: :bad_request)
          return
        end

        # Verify PIN
        unless device.verify_pin(pin)
          api_error(message: 'Invalid PIN', status: :bad_request)
          return
        end

        # Check if user is disabled
        if device.user.status_disabled?
          api_error(message: 'Account is disabled', status: :bad_request)
          return
        end

        # Update last used timestamp
        device.touch_last_used!

        # Generate persistent JWT token (90 days) for Instagram-like login
        token = JsonWebToken.encode_persistent(user_id: device.user.id)

        api_success(
          data: {
            user: user_response(device.user),
            token: token
          },
          message: 'PIN authentication successful',
          status: :ok
        )
      rescue => e
        Rails.logger.error "PIN Auth Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to authenticate', status: :internal_server_error)
      end

      # GET /api/v1/auth/devices
      def list_devices
        require_authentication!
        return if performed? # Stop if authentication failed
        
        devices = current_user.devices.active.order(last_used_at: :desc)
        
        api_success(data: { devices: devices.map(&:device_info) }, status: :ok)
      rescue => e
        Rails.logger.error "List Devices Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to list devices', status: :internal_server_error) unless performed?
      end

      # DELETE /api/v1/auth/devices/:id
      def revoke_device
        require_authentication!
        return if performed?
        
        device = current_user.devices.find_by(id: params[:id])
        
        if device.nil?
          api_error(message: 'Device not found', status: :not_found)
          return
        end

        device.revoke!
        
        api_success(message: 'Device revoked successfully', status: :ok)
      rescue => e
        Rails.logger.error "Revoke Device Error: #{e.message}"
        api_error(message: 'Failed to revoke device', status: :internal_server_error)
      end

      # PATCH /api/v1/auth/devices/:id/enable_biometric
      def enable_biometric
        require_authentication!
        return if performed?
        
        device = current_user.devices.find_by(id: params[:id])
        
        if device.nil?
          api_error(message: 'Device not found', status: :not_found)
          return
        end

        device.enable_biometric!
        
        api_success(
          data: { device: device.device_info },
          message: 'Biometric authentication enabled',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Enable Biometric Error: #{e.message}"
        api_error(message: 'Failed to enable biometric authentication', status: :internal_server_error)
      end

      # PATCH /api/v1/auth/devices/:id/disable_biometric
      def disable_biometric
        require_authentication!
        return if performed?
        
        device = current_user.devices.find_by(id: params[:id])
        
        if device.nil?
          api_error(message: 'Device not found', status: :not_found)
          return
        end

        device.disable_biometric!
        
        api_success(
          data: { device: device.device_info },
          message: 'Biometric authentication disabled',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Disable Biometric Error: #{e.message}"
        api_error(message: 'Failed to disable biometric authentication', status: :internal_server_error)
      end

      # POST /api/v1/auth/devices/:id/setup_pin
      def setup_pin
        require_authentication!
        return if performed?
        
        device = current_user.devices.find_by(id: params[:id])
        
        if device.nil?
          api_error(message: 'Device not found', status: :not_found)
          return
        end

        pin = params[:pin]
        pin_confirmation = params[:pin_confirmation]

        if pin.blank?
          api_error(message: 'PIN is required', status: :bad_request)
          return
        end

        if pin != pin_confirmation
          api_error(message: 'PIN confirmation does not match', status: :bad_request)
          return
        end

        # Validate PIN format (4-6 digits)
        if pin.length < 4 || pin.length > 6
          api_error(message: 'PIN must be 4-6 digits', status: :bad_request)
          return
        end

        unless pin.match?(/\A\d+\z/)
          api_error(message: 'PIN must contain only digits', status: :bad_request)
          return
        end

        device.set_pin!(pin)
        
        api_success(
          data: { device: device.device_info },
          message: 'PIN setup successfully',
          status: :ok
        )
      rescue ArgumentError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        Rails.logger.error "Setup PIN Error: #{e.message}"
        api_error(message: 'Failed to setup PIN', status: :internal_server_error)
      end

      # PATCH /api/v1/auth/devices/:id/enable_pin
      def enable_pin
        require_authentication!
        return if performed?
        
        device = current_user.devices.find_by(id: params[:id])
        
        if device.nil?
          api_error(message: 'Device not found', status: :not_found)
          return
        end

        pin = params[:pin]

        if pin.blank?
          api_error(message: 'PIN is required', status: :bad_request)
          return
        end

        # Validate PIN format (4-6 digits)
        if pin.length < 4 || pin.length > 6
          api_error(message: 'PIN must be 4-6 digits', status: :bad_request)
          return
        end

        unless pin.match?(/\A\d+\z/)
          api_error(message: 'PIN must contain only digits', status: :bad_request)
          return
        end

        device.enable_pin!(pin)
        
        api_success(
          data: { device: device.device_info },
          message: 'PIN authentication enabled',
          status: :ok
        )
      rescue ArgumentError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        Rails.logger.error "Enable PIN Error: #{e.message}"
        api_error(message: 'Failed to enable PIN authentication', status: :internal_server_error)
      end

      # PATCH /api/v1/auth/devices/:id/disable_pin
      def disable_pin
        require_authentication!
        return if performed?
        
        device = current_user.devices.find_by(id: params[:id])
        
        if device.nil?
          api_error(message: 'Device not found', status: :not_found)
          return
        end

        device.disable_pin!
        
        api_success(
          data: { device: device.device_info },
          message: 'PIN authentication disabled',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Disable PIN Error: #{e.message}"
        api_error(message: 'Failed to disable PIN authentication', status: :internal_server_error)
      end

      # POST /api/v1/auth/setup_password
      # Setup password after registration (optional)
      def setup_password
        require_authentication!
        return if performed?
        
        password = params[:password]
        password_confirmation = params[:password_confirmation]

        if password.blank?
          api_error(message: 'Password is required', status: :bad_request)
          return
        end

        if password != password_confirmation
          api_error(message: 'Password confirmation does not match', status: :bad_request)
          return
        end

        # Validate password strength
        if password.length < 8
          api_error(message: 'Password must be at least 8 characters', status: :bad_request)
          return
        end

        unless password.match?(/\A(?=.*[a-zA-Z])(?=.*[0-9])/)
          api_error(message: 'Password must include at least one letter and one number', status: :bad_request)
          return
        end

        # Update user password
        current_user.password = password
        current_user.password_confirmation = password_confirmation

        if current_user.save
          api_success(
            data: { user: user_response(current_user) },
            message: 'Password setup successfully',
            status: :ok
          )
        else
          api_validation_error(errors: current_user.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Setup Password Error: #{e.message}"
        api_error(message: 'Failed to setup password', status: :internal_server_error)
      end

      # POST /api/v1/auth/check_device
      # Check if device is registered and has biometric enabled
      def check_device
        device_uuid = params[:device_uuid]
        username = params[:username]&.strip

        # At least one of device_uuid or username must be provided
        if device_uuid.blank? && username.blank?
          api_error(message: 'Device UUID or username (can be username, email, or phone) is required', status: :bad_request)
          return
        end

        user = nil
        device = nil

        # If device_uuid is provided, try to find device first
        if device_uuid.present?
          device = Device.find_by(device_uuid: device_uuid, status: 'active')
          user = device&.user
        end

        # If username is provided and user not found yet, find user by username/email/phone
        if username.present? && user.nil?
          # Try username first
          user = User.find_by(username: username)
          # If not found, try as email
          user ||= User.find_by(email: username.downcase.strip) if username.match?(URI::MailTo::EMAIL_REGEXP)
          # If still not found, try as phone (normalized)
          user ||= User.find_by(phone: normalize_phone(username)) if username.match?(/\A\+?\d{10,15}\z/)
        end

        # If both device_uuid and username provided, verify they match
        if device_uuid.present? && username.present? && user.present? && device.present?
          if device.user_id != user.id
            # Device exists but belongs to different user
            api_success(
              data: {
                user_exists: true,
                device_registered: false,
                recommended_method: 'register_device',
                message: 'Device UUID does not belong to this user. Please register device.'
              },
              status: :ok
            )
            return
          end
        end

        # Scenario 1: New user + new device (no user found)
        if user.nil?
          api_success(
            data: {
              user_exists: false,
              device_registered: false,
              recommended_method: 'register_with_otp',
              message: 'User not found. Please register with OTP.'
            },
            status: :ok
          )
          return
        end

        # Scenario 2: Existing user, but device_uuid not present for this user
        # This happens when:
        # - device_uuid is provided but device doesn't exist for this user
        # - only username is provided (can't check device without device_uuid)
        if user.present? && (device_uuid.blank? || device.nil?)
          api_success(
            data: {
              user_exists: true,
              device_registered: false,
              recommended_method: 'register_device',
              message: device_uuid.present? ? 'Device not registered for this user. Please register device.' : 'Please provide device_uuid and register device.'
            },
            status: :ok
          )
          return
        end

        # Scenario 3: Existing user with existing device
        if user.present? && device.present?
          # Check if user has password set (exclude temporary/random passwords)
          has_real_password = user.password_digest.present? && 
                             user.password_digest.length > 60 # bcrypt hashes are 60 chars

          # For existing users: only show biometric, pin, or password, NOT otp
          authentication_methods = []
          authentication_methods << 'biometric' if device.biometric_enabled?
          authentication_methods << 'pin' if device.pin_enabled?
          authentication_methods << 'password' if has_real_password

          # If user has no authentication method set up, they must use OTP
          authentication_methods << 'otp' if authentication_methods.empty?

          # Determine recommended method (priority: biometric > pin > password > otp)
          recommended_method = if device.biometric_enabled?
                                'biometric'
                              elsif device.pin_enabled?
                                'pin'
                              elsif has_real_password
                                'password'
                              else
                                'otp'
                              end

          # Generate a new device token (this invalidates the old token)
          # Note: The original token cannot be retrieved from token_hash (it's a one-way hash)
          # If client needs the token, we generate a new one here
          new_token = Device.generate_token
          new_token_hash = Device.hash_token(new_token)
          device.update!(token_hash: new_token_hash, last_used_at: Time.current)

          api_success(
            data: {
              user_exists: true,
              device_registered: true,
              device_has_biometric: device.biometric_enabled?,
              device_has_pin: device.pin_enabled?,
              has_password: has_real_password,
              user: user_response(user),
              device_token: new_token,
              authentication_methods: authentication_methods,
              recommended_method: recommended_method
            },
            status: :ok
          )
          return
        end

        # Fallback: Should not reach here, but handle gracefully
        api_error(message: 'Unable to determine device status', status: :internal_server_error)
      rescue => e
        Rails.logger.error "Check Device Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to check device', status: :internal_server_error)
      end

      private

      def register_params
        params.require(:user).permit(:email, :phone, :username, :password, :password_confirmation, :name, :role)
      end

      def login_params
        params.require(:user).permit(:username, :email, :phone, :password)
      end

      def otp_params
        params.permit(:phone, :email)
      end

      def verify_otp_params
        params.permit(:phone, :email, :code)
      end

      def device_registration_params
        params.permit(
          :device_uuid,
          :device_name,
          :device_type,
          :platform,
          :platform_version,
          :app_version,
          :biometric_enabled
        )
      end

      def biometric_auth_params
        params.permit(:device_token, :device_uuid)
      end

      def pin_auth_params
        params.permit(:device_token, :device_uuid, :pin)
      end

      def normalize_phone(phone)
        return nil if phone.blank?
        # Remove all non-digit characters
        phone.gsub(/\D/, '')
      end

      def user_response(user)
        {
          id: user.id,
          uniq_identifier: user.uniq_identifier,
          email: user.email,
          phone: user.phone,
          name: user.name,
          role: user.role,
          status: user.status,
          description: user.description,
          address: user.address,
          preferences: user.preferences,
          created_at: user.created_at
        }
      end
    end
  end
end

