class VenueBlocklist < ApplicationRecord
  belongs_to :venue
  belongs_to :user
  belongs_to :blocked_by, class_name: 'User'
  belongs_to :related_event, class_name: 'Event', optional: true
  belongs_to :related_booking, class_name: 'Booking', optional: true
  
  validates :reason, presence: true
  validates :incident_type, inclusion: { 
    in: %w[no_show late_cancellation behavior fraud other] 
  }, allow_nil: true
  
  enum :incident_type, {
    no_show: 'no_show',
    late_cancellation: 'late_cancellation',
    behavior: 'behavior',
    fraud: 'fraud',
    other: 'other'
  }, prefix: true
  
  scope :active, -> { where('blocked_until IS NULL OR blocked_until > ?', Time.current) }
  scope :permanent, -> { where(is_permanent: true) }
  scope :temporary, -> { where(is_permanent: false) }
  scope :expired, -> { where.not(blocked_until: nil).where('blocked_until <= ?', Time.current) }
  
  def active?
    is_permanent? || (blocked_until.present? && blocked_until > Time.current)
  end
  
  def expired?
    !is_permanent? && blocked_until.present? && blocked_until <= Time.current
  end
  
  def time_remaining
    return nil if is_permanent?
    return 0 if expired?
    ((blocked_until - Time.current) / 1.hour).round(1)
  end
end

