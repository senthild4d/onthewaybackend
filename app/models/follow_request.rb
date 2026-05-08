class FollowRequest < ApplicationRecord
  belongs_to :requester, class_name: 'User', foreign_key: 'requester_id'
  belongs_to :requested, class_name: 'User', foreign_key: 'requested_id'

  # Validations
  validates :requester_id, presence: true
  validates :requested_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending accepted rejected cancelled] }
  validate :no_duplicate_pending_request

  def no_duplicate_pending_request
    if pending? && FollowRequest.where(requester_id: requester_id, requested_id: requested_id, status: 'pending').where.not(id: id).exists?
      errors.add(:base, 'already has a pending follow request to this user')
    end
  end
  validate :cannot_request_self

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_requester, ->(user_id) { where(requester_id: user_id) }
  scope :for_requested, ->(user_id) { where(requested_id: user_id) }

  # Callbacks
  before_update :set_responded_at, if: :status_changed?

  def accept!
    return false unless pending?
    transaction do
      update!(status: 'accepted', responded_at: Time.current)
      # Create the actual Follow relationship (skip notification since we send follow_request_accepted)
      follow = Follow.find_or_initialize_by(follower_id: requester_id, following_id: requested_id)
      follow.skip_notification = true # Prevent duplicate notification
      follow.save!
      # Create notification for requester
      create_acceptance_notification
    end
    true
  rescue => e
    Rails.logger.error "Failed to accept follow request: #{e.message}"
    false
  end

  def reject!
    return false unless pending?
    update!(status: 'rejected', responded_at: Time.current)
  end

  def cancel!
    return false unless pending?
    update!(status: 'cancelled', responded_at: Time.current)
  end

  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end

  def rejected?
    status == 'rejected'
  end

  def cancelled?
    status == 'cancelled'
  end

  private

  def cannot_request_self
    if requester_id == requested_id
      errors.add(:base, 'You cannot request to follow yourself')
    end
  end

  def set_responded_at
    self.responded_at = Time.current if status != 'pending'
  end

  def create_acceptance_notification
    # Prevent duplicate notifications: check if one was created recently (within 1 minute)
    recent_notification = Notification.where(
      user_id: requester.id,
      notification_type: 'follow_request_accepted'
    ).where('metadata->>? = ?', 'requested_id', requested.id.to_s)
     .where('created_at > ?', 1.minute.ago)
     .exists?
    
    return if recent_notification

    requested_display = requested.name.presence || requested.username.presence || 'Someone'
    notification = Notification.create!(
      user: requester,
      notification_type: 'follow_request_accepted',
      title: 'Follow Request Accepted',
      message: "#{requested_display} accepted your follow request",
      metadata: {
        requested_id: requested.id,
        requested_name: requested.name,
        requested_username: requested.username
      }
    )
    
    # Send push notification if user has it enabled
    if notification && should_send_push_notification_for_acceptance?(requester)
      send_follow_request_accepted_push_notification(requester, notification, requested)
    end
  rescue => e
    Rails.logger.error "Failed to create acceptance notification: #{e.message}"
  end
  
  def should_send_push_notification_for_acceptance?(user)
    return true unless user.preferences.is_a?(Hash)
    
    prefs = user.preferences['push_notification_settings']
    return true unless prefs.is_a?(Hash)
    
    interactions = prefs['interactions']
    return true unless interactions.is_a?(Hash)
    
    # Default to true if not explicitly disabled
    interactions['new_followers'] != false
  end
  
  def send_follow_request_accepted_push_notification(user, notification, accepted_by)
    return unless FcmService.configured?
    
    meta = notification.metadata_hash
    flutter_type = notification.respond_to?(:flutter_type) ? notification.flutter_type : notification.notification_type
    
    FcmService.send_to_user(
      user,
      title: notification.title,
      body: notification.message,
      data: {
        notification_id: notification.id.to_s,
        notification_type: notification.notification_type,
        type: flutter_type,
        requested_id: meta['requested_id'].to_s,
        requested_name: meta['requested_name'].to_s,
        requested_username: meta['requested_username'].to_s
      }
    )
  rescue => e
    Rails.logger.error "Failed to send follow request accepted push notification: #{e.message}"
  end
end
