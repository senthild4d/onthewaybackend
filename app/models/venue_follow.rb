class VenueFollow < ApplicationRecord
  belongs_to :user
  belongs_to :venue
  
  # Validations
  validates :user_id, presence: true
  validates :venue_id, presence: true
  validates :user_id, uniqueness: { scope: :venue_id, message: "is already following this venue" }
  
  # Callbacks
  after_create :create_follow_notification, if: -> { venue.present? }
  
  private
  
  def create_follow_notification
    # Notify the venue owner when someone follows their venue
    Notification.create!(
      user: venue.owner,
      notification_type: 'venue_follow',
      title: 'New Venue Follower',
      message: "#{user.name || user.username} started following #{venue.name}",
      metadata: {
        follower_id: user.id,
        follower_name: user.name,
        follower_username: user.username,
        venue_id: venue.id,
        venue_name: venue.name
      }
    )
  rescue => e
    Rails.logger.error "Failed to create venue follow notification: #{e.message}"
  end
end

