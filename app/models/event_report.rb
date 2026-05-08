class EventReport < ApplicationRecord
  belongs_to :event
  belongs_to :reporter, class_name: 'User', foreign_key: 'reporter_id'
  belongs_to :reviewed_by, class_name: 'User', foreign_key: 'reviewed_by_id', optional: true
  
  # Validations
  validates :reason, presence: true, inclusion: { in: %w[spam inappropriate misleading duplicate violence harassment other] }
  validates :reporter_id, uniqueness: { 
    scope: :event_id, 
    message: "has already reported this event" 
  }
  validate :cannot_report_own_event
  
  # Enums
  enum :status, { pending: 'pending', reviewed: 'reviewed', resolved: 'resolved', dismissed: 'dismissed' }, prefix: true
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :reviewed, -> { where(status: 'reviewed') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :dismissed, -> { where(status: 'dismissed') }
  scope :by_reason, ->(reason) { where(reason: reason) }
  
  # Constants
  REASONS = %w[
    spam
    inappropriate
    misleading
    duplicate
    violence
    harassment
    other
  ].freeze
  
  # Methods
  def review!(admin_user, status: 'reviewed', admin_notes: nil)
    update!(
      reviewed_by: admin_user,
      status: status,
      admin_notes: admin_notes,
      reviewed_at: Time.current
    )
  end
  
  private
  
  def cannot_report_own_event
    return unless event.present? && reporter.present?
    
    if event.creator_id == reporter.id
      errors.add(:base, 'You cannot report your own event')
    end
  end
end

