class UserReport < ApplicationRecord
  # Associations
  belongs_to :reporter, class_name: 'User'
  belongs_to :reported, class_name: 'User'
  belongs_to :reviewed_by, class_name: 'User', optional: true

  # Enums
  enum :status, {
    pending: 'pending',
    reviewed: 'reviewed',
    resolved: 'resolved',
    dismissed: 'dismissed'
  }, prefix: true

  # Validations
  validates :reporter_id, presence: true
  validates :reported_id, presence: true
  validates :reason, presence: true, inclusion: { in: %w[spam harassment inappropriate fake_account other] }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validate :cannot_report_self
  validate :unique_report_per_user, on: :create

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :by_reporter, ->(user) { where(reporter_id: user.id) }

  REASONS = %w[spam harassment inappropriate fake_account other].freeze

  def review!(reviewer, status:, admin_notes: nil)
    update!(
      status: status,
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      admin_notes: admin_notes
    )
  end

  private

  def cannot_report_self
    if reporter_id == reported_id
      errors.add(:base, "Cannot report yourself")
    end
  end

  def unique_report_per_user
    if UserReport.exists?(reporter_id: reporter_id, reported_id: reported_id, status: ['pending', 'reviewed'])
      errors.add(:base, "You have already reported this user")
    end
  end
end

