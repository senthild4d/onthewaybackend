class Follow < ApplicationRecord
  belongs_to :follower, class_name: 'User'
  belongs_to :following, class_name: 'User'
  
  # Validations
  validates :follower_id, presence: true
  validates :following_id, presence: true
  validates :follower_id, uniqueness: { scope: :following_id, message: "is already following this user" }
  validate :cannot_follow_self
  
  # Callbacks
  # Skip notification if created from follow request acceptance (we send follow_request_accepted instead)
  after_create :create_follow_notification, if: -> { following.present? && !skip_follow_notification? }
  
  attr_accessor :skip_notification
  
  private
  
  def cannot_follow_self
    if follower_id == following_id
      errors.add(:base, "You cannot follow yourself")
    end
  end
  
  def skip_follow_notification?
    skip_notification == true
  end
  
  def create_follow_notification
    # Don't create notification if this Follow was created from accepting a follow request
    # (we already send follow_request_accepted notification)
    return if skip_follow_notification?
    
    # Prevent duplicate notifications: check if a follow notification was created recently (within 1 minute)
    recent_notification = Notification.where(
      user_id: following.id,
      notification_type: 'follow'
    ).where('metadata->>? = ?', 'follower_id', follower.id.to_s)
     .where('created_at > ?', 1.minute.ago)
     .exists?
    
    return if recent_notification

    follower_display = follower.name.presence || follower.username.presence || 'Someone'
    Notification.create!(
      user: following,
      notification_type: 'follow',
      title: 'New Follower',
      message: "#{follower_display} started following you",
      metadata: {
        follower_id: follower.id,
        follower_name: follower.name,
        follower_username: follower.username
      }
    )
  rescue => e
    Rails.logger.error "Failed to create follow notification: #{e.message}"
  end
end

