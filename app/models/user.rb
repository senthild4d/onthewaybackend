class User < ApplicationRecord
  has_secure_password validations: false  # Make password optional for phone auth

  # ActiveStorage attachments
  has_one_attached :profile_picture

  # Associations (kept for real-estate scope)
  has_many :otps, dependent: :destroy
  has_many :devices, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_properties, through: :favorites, source: :property
  has_many :property_viewings, dependent: :destroy
  has_many :blocked_users, class_name: 'UserBlock', foreign_key: 'blocker_id', dependent: :destroy
  has_many :blocked_by_users, class_name: 'UserBlock', foreign_key: 'blocked_id', dependent: :destroy
  has_many :blocked_user_records, through: :blocked_users, source: :blocked
  has_many :blocked_by_user_records, through: :blocked_by_users, source: :blocker
  has_many :user_reports, foreign_key: 'reporter_id', dependent: :destroy
  has_many :reported_by_users, class_name: 'UserReport', foreign_key: 'reported_id', dependent: :destroy
  has_many :user_deactivations, dependent: :destroy

  # Enums (real-estate app)
  enum :role, { user: 'user', owner: 'owner' }, prefix: true
  enum :status, { active: 'active', disabled: 'disabled' }, prefix: true

  def admin?
    is_admin == true
  end

  store_accessor :current_location, :lat, :lng, :formatted_address, :place_id, :source, :recorded_at

  # Validations
  validates :email, uniqueness: { case_sensitive: false, allow_nil: true }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }
  validates :phone, uniqueness: { allow_nil: true }
  # Allow international phone numbers with flexible length (just digits + optional leading +)
  validates :phone, format: { with: /\A\+?\d+\z/, message: "must contain only digits (and optional leading +)" }, if: -> { phone.present? }
  validates :username, uniqueness: { case_sensitive: false, allow_nil: true }
  validates :username, format: { with: /\A[a-zA-Z0-9_]+\z/, message: "can only contain letters, numbers, and underscores" }, if: -> { username.present? }
  validates :username, length: { minimum: 3, maximum: 30 }, if: -> { username.present? }
  validates :date_of_birth, presence: false
  validate :date_of_birth_not_future
  validate :phone_or_email_present
  validates :password, length: { minimum: 8 }, if: -> { password.present? && password_required? }
  validates :password, format: { 
    with: /\A(?=.*[a-zA-Z])(?=.*[0-9])/, 
    message: "must include at least one letter and one number" 
  }, if: -> { password.present? && password_required? }
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Password is optional for OTP-based authentication (phone or email)
  def password_required?
    # Password only required if using traditional email/password login
    false  # Allow OTP-based authentication without password
  end

  # Callbacks
  before_validation :downcase_email
  before_validation :normalize_phone

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :users, -> { where(role: 'user') }
  scope :owners, -> { where(role: 'owner') }
  scope :admins, -> { where(is_admin: true) }

  def current_location_snapshot
    location_data = current_location.presence || {}
    if location_data.blank?
      LocationSnapshot.new(source: 'device_pending', recorded_at: Time.current)
    else
      LocationSnapshot.from_hash(location_data)
    end
  end

  def set_current_location!(snapshot)
    update!(current_location: snapshot.as_json)
  end

  def clear_current_location!
    update!(current_location: {})
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def normalize_phone
    # Remove all non-digit characters from phone
    self.phone = phone.gsub(/\D/, '') if phone.present?
  end

  def phone_or_email_present
    if phone.blank? && email.blank?
      errors.add(:base, "Either phone or email must be present")
    end
  end
  
  def date_of_birth_not_future
    if date_of_birth.present? && date_of_birth > Date.today
      errors.add(:date_of_birth, "cannot be in the future")
    end
  end
  
  def normalize_deactivation_reason(reason)
    return nil if reason.blank?
    
    # Map UI-friendly reasons to database format
    reason_map = {
      'I am leaving temporarily' => 'leaving_temporarily',
      'Privacy and security issues' => 'privacy_security',
      'Having trouble getting started' => 'trouble_getting_started',
      'I have multiple accounts' => 'multiple_accounts',
      'Other reason' => 'other'
    }
    
    # Return mapped value or original if already in correct format
    reason_map[reason] || reason
  end
  
  public
  
  # Follow methods
  def follow!(user)
    return false if user == self
    return false if following?(user)
    
    follows_as_follower.create!(following: user)
  end

  # Request to follow a user (requires acceptance)
  def request_follow!(user)
    return false if user == self
    return false if following?(user)
    
    # Check if there's already a pending request
    existing_request = follow_requests_sent.pending.find_by(requested_id: user.id)
    return false if existing_request
    
    # Check if there's already a follow
    return false if following?(user)
    
    follow_requests_sent.create!(requested: user)
  end

  def cancel_follow_request!(user)
    request = follow_requests_sent.pending.find_by(requested_id: user.id)
    return false unless request
    request.cancel!
  end

  def has_pending_request_to?(user)
    follow_requests_sent.pending.exists?(requested_id: user.id)
  end

  def has_pending_request_from?(user)
    follow_requests_received.pending.exists?(requester_id: user.id)
  end
  
  def unfollow!(user)
    follows_as_follower.find_by(following: user)&.destroy
  end
  
  def following?(user)
    following.include?(user)
  end
  
  def followed_by?(user)
    followers.include?(user)
  end
  
  def followers_count
    followers.count
  end
  
  def following_count
    following.count
  end
  
  # Venue follow methods
  def follow_venue!(venue)
    return false if following_venue?(venue)
    
    venue_follows.create!(venue: venue)
  end
  
  def unfollow_venue!(venue)
    venue_follows.find_by(venue: venue)&.destroy
  end
  
  def following_venue?(venue)
    followed_venues.include?(venue)
  end
  
  def followed_venues_count
    followed_venues.count
  end
  
  # Block methods
  def block!(user)
    return false if user == self
    return false if blocked?(user)
    
    blocked_users.create!(blocked: user)
  end
  
  def unblock!(user)
    blocked_users.find_by(blocked: user)&.destroy
  end
  
  def blocked?(user)
    blocked_user_records.include?(user)
  end
  
  def blocked_by?(user)
    blocked_by_user_records.include?(user)
  end
  
  def blocked_users_ids
    blocked_user_records.pluck(:id)
  end
  
  def unread_notifications_count
    notifications.unread.count
  end
  
  # Deactivation methods
  def deactivate!(reason: nil, additional_feedback: nil)
    transaction do
      user_deactivations.create!(
        reason: normalize_deactivation_reason(reason),
        additional_feedback: additional_feedback,
        deactivated_at: Time.current
      )
      update!(status: 'disabled')
    end
  end
  
  def reactivate!(reactivated_by: 'user', notes: nil)
    transaction do
      active_deactivation = user_deactivations.active.last
      active_deactivation&.reactivate!(reactivated_by: reactivated_by, notes: notes)
      update!(status: 'active')
    end
  end
  
  def active_deactivation
    user_deactivations.active.last
  end
  
  def deactivation_history
    user_deactivations.recent
  end
  
  def times_deactivated
    user_deactivations.count
  end
  
  # Profile picture URL (path or full URL). Returns default avatar when no picture.
  def avatar_url
    if profile_picture.attached?
      Rails.application.routes.url_helpers.rails_blob_path(profile_picture, only_path: true)
    elsif profile_picture_url.present?
      profile_picture_url
    else
      DEFAULT_AVATAR_PATH
    end
  end
end
