class EventArtist < ApplicationRecord
  belongs_to :event
  belongs_to :artist, class_name: 'User', foreign_key: 'artist_id', optional: true

  # Validations
  validates :event_id, presence: true
  validates :scheduled_start_at, presence: true
  validates :scheduled_end_at, presence: true
  validates :timezone, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[confirmed pending cancelled] }
  validates :artist_id, uniqueness: { scope: :event_id, message: "is already added to this event" }, if: :artist_id?
  validate :artist_id_or_artist_name_required
  validate :artist_must_be_artist_role, if: :artist_id?
  validate :schedule_within_event_time
  validate :end_after_start
  
  # Enums
  enum :status, { confirmed: 'confirmed', pending: 'pending', cancelled: 'cancelled' }, prefix: true
  
  # Scopes
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :pending, -> { where(status: 'pending') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :ordered, -> { order(display_order: :asc, scheduled_start_at: :asc) }
  scope :upcoming, -> { where('scheduled_start_at > ?', Time.current) }
  scope :past, -> { where('scheduled_end_at < ?', Time.current) }
  scope :live, -> { confirmed.where('scheduled_start_at <= ? AND scheduled_end_at >= ?', Time.current, Time.current) }
  
  # Callbacks
  before_validation :set_timezone_from_event, on: :create
  
  # Methods
  def duration_minutes
    return 0 if scheduled_start_at.nil? || scheduled_end_at.nil?
    ((scheduled_end_at - scheduled_start_at) / 60).to_i
  end
  
  def duration_hours
    (duration_minutes / 60.0).round(1)
  end
  
  def is_live?
    status_confirmed? && 
    Time.current.between?(scheduled_start_at, scheduled_end_at)
  end
  
  def is_upcoming?
    scheduled_start_at > Time.current
  end
  
  def is_past?
    scheduled_end_at < Time.current
  end

  # Display name: from linked User or free-form artist_name
  def display_name
    artist&.name.presence || artist_name.presence || 'Unknown Artist'
  end

  def cancel!
    update!(status: 'cancelled')
  end
  
  def confirm!
    update!(status: 'confirmed')
  end
  
  private

  def artist_id_or_artist_name_required
    return if artist_id.present? || artist_name.present?
    errors.add(:base, 'Either artist_id or artist_name is required')
  end

  def artist_must_be_artist_role
    unless artist&.role_artist?
      errors.add(:artist_id, "must be a user with artist role")
    end
  end
  
  def schedule_within_event_time
    return unless event.present? && scheduled_start_at.present? && scheduled_end_at.present?
    
    if scheduled_start_at < event.starts_at
      errors.add(:scheduled_start_at, "cannot be before event start time")
    end
    
    if scheduled_end_at > event.ends_at
      errors.add(:scheduled_end_at, "cannot be after event end time")
    end
  end
  
  def end_after_start
    return unless scheduled_start_at.present? && scheduled_end_at.present?
    
    if scheduled_end_at <= scheduled_start_at
      errors.add(:scheduled_end_at, "must be after scheduled start time")
    end
  end
  
  def set_timezone_from_event
    self.timezone = event.timezone if event.present? && timezone.blank?
  end
end

