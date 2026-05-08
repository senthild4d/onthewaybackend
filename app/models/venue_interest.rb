class VenueInterest < ApplicationRecord
  belongs_to :user
  belongs_to :venue
  
  # Validations
  validates :user_id, uniqueness: { 
    scope: :venue_id, 
    message: "has already RSVP'd to this venue" 
  }
  validates :rsvp_status, presence: true, inclusion: { in: %w[yes no maybe] }
  validates :guest_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  
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
  
  private
  
  def set_responded_at
    self.responded_at = Time.current if responded_at.nil?
  end
end

