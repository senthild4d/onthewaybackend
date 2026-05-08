class EventInterest < ApplicationRecord
  belongs_to :user
  belongs_to :event
  
  # Validations
  validates :user_id, uniqueness: { 
    scope: :event_id, 
    message: "has already expressed interest or RSVP'd to this event" 
  }
  validates :rsvp_status, inclusion: { in: %w[yes no maybe] }, allow_nil: true
  validates :guest_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  
  # Validate that if rsvp_status is present, guest_count and notes are allowed
  # If rsvp_status is nil, it's a simple interest (no RSVP)
  
  # Enums
  enum :rsvp_status, { yes: 'yes', no: 'no', maybe: 'maybe' }, prefix: true
  
  # Scopes
  scope :attending, -> { where(rsvp_status: 'yes') }
  scope :not_attending, -> { where(rsvp_status: 'no') }
  scope :maybe_attending, -> { where(rsvp_status: 'maybe') }
  scope :responded, -> { where.not(responded_at: nil) }
  
  # Callbacks
  before_save :set_responded_at, if: :rsvp_status_changed?
  
  # Methods
  def attending?
    rsvp_status_yes?
  end
  
  def not_attending?
    rsvp_status_no?
  end
  
  def maybe_attending?
    rsvp_status_maybe?
  end
  
  def total_attendees
    guest_count + 1 # Include the user themselves
  end
  
  validate :event_not_past
  
  private
  
  def set_responded_at
    self.responded_at = Time.current if responded_at.nil?
  end
  
  def event_not_past
    return unless event.present?
    
    if event.ends_at < Time.current
      errors.add(:base, 'Cannot RSVP to past events')
    end
  end
end

