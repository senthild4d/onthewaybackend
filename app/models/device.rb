class Device < ApplicationRecord
  belongs_to :user

  # Enums
  enum :status, { active: 'active', revoked: 'revoked', expired: 'expired' }, prefix: true

  # Validations
  validates :device_uuid, presence: true, uniqueness: { scope: :user_id }
  validates :platform, presence: true, inclusion: { in: %w[ios android] }
  validates :token_hash, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :biometric_enabled, -> { where(biometric_enabled: true) }
  scope :pin_enabled, -> { where.not(pin_hash: nil) }
  scope :for_platform, ->(platform) { where(platform: platform) }

  # Constants
  TOKEN_EXPIRY_DAYS = 90  # Device tokens expire after 90 days

  # Generate a secure device token
  def self.generate_token
    SecureRandom.urlsafe_base64(32)
  end

  # Hash a device token for storage
  def self.hash_token(token)
    Digest::SHA256.hexdigest(token)
  end

  # Create a new device registration
  def self.register(user:, device_params:, biometric_enabled: false)
    token = generate_token
    token_hash = hash_token(token)

    device = create!(
      user: user,
      device_uuid: device_params[:device_uuid],
      device_name: device_params[:device_name],
      device_type: device_params[:device_type],
      platform: device_params[:platform],
      platform_version: device_params[:platform_version],
      app_version: device_params[:app_version],
      biometric_enabled: biometric_enabled,
      token_hash: token_hash,
      last_used_at: Time.current,
      status: 'active'
    )

    # Return device with plain token (only time it's available)
    { device: device, token: token }
  end

  # Find device by token
  def self.find_by_token(token)
    return nil if token.blank?
    token_hash = hash_token(token)
    find_by(token_hash: token_hash, status: 'active')
  end

  # Check if device is expired
  def expired?
    return false if last_used_at.nil?
    last_used_at < TOKEN_EXPIRY_DAYS.days.ago
  end

  # Update last used timestamp
  def touch_last_used!
    update(last_used_at: Time.current)
  end

  # Revoke device
  def revoke!
    update!(status: 'revoked')
  end

  # Enable biometric authentication
  def enable_biometric!
    update!(biometric_enabled: true)
  end

  # Disable biometric authentication
  def disable_biometric!
    update!(biometric_enabled: false)
  end

  # Set PIN for device
  def set_pin!(pin)
    if pin.blank? || pin.length < 4 || pin.length > 6
      raise ArgumentError, 'PIN must be 4-6 digits'
    end

    unless pin.match?(/\A\d+\z/)
      raise ArgumentError, 'PIN must contain only digits'
    end

    self.pin_hash = BCrypt::Password.create(pin)
    save!
  end

  # Verify PIN
  def verify_pin(pin)
    return false if pin_hash.blank? || pin.blank?
    BCrypt::Password.new(pin_hash) == pin
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # Check if PIN is enabled
  def pin_enabled?
    pin_hash.present?
  end

  # Enable PIN authentication (requires PIN to be set first)
  def enable_pin!(pin)
    set_pin!(pin)
  end

  # Disable PIN authentication
  def disable_pin!
    update!(pin_hash: nil)
  end

  # Check if device can authenticate
  def can_authenticate?
    status_active? && !expired?
  end

  # Update FCM token for this device
  def update_fcm_token!(token)
    update!(fcm_token: token.presence)
  end

  # Clear FCM token
  def clear_fcm_token!
    update!(fcm_token: nil)
  end

  # Check if device has FCM token
  def has_fcm_token?
    fcm_token.present?
  end

  # Get device info for response
  def device_info
    {
      id: id,
      device_name: device_name,
      device_type: device_type,
      platform: platform,
      biometric_enabled: biometric_enabled,
      pin_enabled: pin_enabled?,
      last_used_at: last_used_at,
      status: status,
      created_at: created_at,
      has_fcm_token: has_fcm_token?
    }
  end
end
