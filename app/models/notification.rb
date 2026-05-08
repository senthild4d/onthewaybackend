class Notification < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :user_id, presence: true
  validates :notification_type, presence: true
  validates :title, presence: true
  validates :message, presence: true
  
  # Enums (backend values). Map to Flutter NotificationType camelCase in API:
  # follow_request -> followRequest, event_start/event_reminder -> eventStart,
  # follow -> startedFollowing, event_cancelled -> eventCancelled, reel_like -> reelLike
  enum :notification_type, {
    follow: 'follow',
    follow_request: 'follow_request',
    follow_request_accepted: 'follow_request_accepted',
    venue_follow: 'venue_follow',
    event_invite: 'event_invite',
    event_reminder: 'event_reminder',
    event_start: 'event_start',
    booking_confirmed: 'booking_confirmed',
    booking_cancelled: 'booking_cancelled',
    booking_request: 'booking_request',
    event_updated: 'event_updated',
    event_cancelled: 'event_cancelled',
    message: 'message',
    group_chat_invite: 'group_chat_invite',
    rating: 'rating',
    like: 'like',
    reel_like: 'reel_like',
    comment: 'comment',
    system: 'system'
  }, prefix: true

  # Flutter NotificationType (camelCase) for API response
  FLUTTER_TYPE_MAP = {
    'follow_request' => 'followRequest',
    'event_reminder' => 'eventStart',
    'event_start' => 'eventStart',
    'follow' => 'startedFollowing',
    'event_cancelled' => 'eventCancelled',
    'reel_like' => 'reelLike',
    'like' => 'reelLike',  # treat generic like as reel like when metadata has reel_id
    'booking_request' => 'bookingRequest'
  }.freeze

  def flutter_type
    FLUTTER_TYPE_MAP[notification_type] || notification_type
  end

  # Map Flutter type (camelCase) to backend notification_type(s) for filtering
  def self.backend_types_for_flutter_type(flutter_type)
    case flutter_type.to_s
    when 'followRequest' then ['follow_request']
    when 'eventStart' then %w[event_reminder event_start]
    when 'startedFollowing' then ['follow']
    when 'eventCancelled' then ['event_cancelled']
    when 'reelLike' then %w[reel_like like]
    when 'bookingRequest' then ['booking_request']
    else [flutter_type.to_s]
    end
  end
  
  # Scopes
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  
  # Methods
  def mark_as_read!
    update!(read: true, read_at: Time.current) unless read?
  end
  
  def mark_as_unread!
    update!(read: false, read_at: nil) if read?
  end
  
  def metadata_hash
    return {} if metadata.blank?
    metadata.is_a?(Hash) ? metadata : JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end
end

