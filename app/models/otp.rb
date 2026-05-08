class Otp < ApplicationRecord
  belongs_to :user, optional: true

  # Validations
  validates :code, presence: true, length: { is: 6 }
  validates :expires_at, presence: true
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }
  validate :phone_or_email_present
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }

  # Scopes
  scope :valid_otps, -> { where('expires_at > ? AND verified = ?', Time.current, false) }
  scope :for_phone, ->(phone) { where(phone: phone) }
  scope :for_email, ->(email) { where(email: email) }
  
  # Constants
  OTP_EXPIRY_MINUTES = 5
  MAX_ATTEMPTS = 1000  # User can try verifying 5 times
  MAX_OTP_REQUESTS_PER_USER = 1000  # User can request max 3 OTPs total

  # Generate a 6-digit OTP code
  def self.generate_code
    rand(100000..999999).to_s
  end

  # Check if user can request OTP (max 3 OTPs per user lifetime)
  def self.check_rate_limit(identifier, type: :phone)
    # Count total OTP requests for this identifier (phone or email)
    total_requests = case type
                     when :phone
                       where(phone: identifier).count
                     when :email
                       where(email: identifier).count
                     else
                       0
                     end
    
    if total_requests >= MAX_OTP_REQUESTS_PER_USER
      identifier_type = type == :phone ? "phone number" : "email address"
      return {
        allowed: false,
        reason: :max_requests_exceeded,
        message: "Maximum OTP requests exceeded for this #{identifier_type}. Please contact support.",
        requests_used: total_requests,
        max_requests: MAX_OTP_REQUESTS_PER_USER
      }
    end

    {
      allowed: true,
      requests_remaining: MAX_OTP_REQUESTS_PER_USER - total_requests
    }
  end

  # Create OTP for phone number
  def self.create_for_phone(phone)
    # Invalidate previous OTPs for this phone
    where(phone: phone, verified: false).update_all(verified: true)
    
    create!(
      phone: phone,
      code: generate_code,
      expires_at: OTP_EXPIRY_MINUTES.minutes.from_now,
      verified: false,
      attempts: 0
    )
  end

  # Create OTP for email
  def self.create_for_email(email)
    # Invalidate previous OTPs for this email
    where(email: email, verified: false).update_all(verified: true)
    
    create!(
      email: email,
      code: generate_code,
      expires_at: OTP_EXPIRY_MINUTES.minutes.from_now,
      verified: false,
      attempts: 0
    )
  end

  # Check if OTP is valid
  def valid_otp?
    !verified && expires_at > Time.current && attempts < MAX_ATTEMPTS
  end

  # Check if OTP is expired
  def expired?
    expires_at <= Time.current
  end

  # Check if max attempts reached
  def max_attempts_reached?
    attempts >= MAX_ATTEMPTS
  end

  # Increment attempt count
  def increment_attempts!
    increment!(:attempts)
  end

  # Mark as verified
  def mark_verified!
    update!(verified: true)
  end

  private

  # Validate that at least one of phone or email is present
  def phone_or_email_present
    if phone.blank? && email.blank?
      errors.add(:base, "Either phone or email must be present")
    end
  end
end
