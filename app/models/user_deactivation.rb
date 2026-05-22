class UserDeactivation < ApplicationRecord
  REASONS = {
    'leaving_temporarily' => 'I am leaving temporarily',
    'privacy_security' => 'Privacy and security issues',
    'trouble_getting_started' => 'Having trouble getting started',
    'multiple_accounts' => 'I have multiple accounts',
    'other' => 'Other reason'
  }.freeze

  belongs_to :user

  # Validations
  validates :deactivated_at, presence: true
  validates :reason, inclusion: { in: REASONS.keys, allow_nil: true }

  # Scopes
  scope :active, -> { where(reactivated_at: nil) }
  scope :reactivated, -> { where.not(reactivated_at: nil) }
  scope :by_reason, ->(reason) { where(reason: reason) }
  scope :recent, -> { order(deactivated_at: :desc) }

  # Class methods for analytics
  def self.deactivation_reasons_count
    active.group(:reason).count
  end

  def self.average_deactivation_duration
    # Use raw SQL to avoid scope conflicts
    result = connection.select_one(<<-SQL.squish)
      SELECT AVG(EXTRACT(EPOCH FROM (reactivated_at - deactivated_at)) / 86400) as avg_days
      FROM user_deactivations
      WHERE reactivated_at IS NOT NULL
    SQL
    
    result&.dig('avg_days')&.to_f&.round(2)
  end

  # Instance methods
  def active?
    reactivated_at.nil?
  end

  def reactivate!(reactivated_by: 'user', notes: nil)
    update!(
      reactivated_at: Time.current,
      reactivated_by: reactivated_by,
      reactivation_notes: notes
    )
  end

  def duration_days
    return nil unless reactivated_at
    ((reactivated_at - deactivated_at) / 1.day).round(2)
  end

  def human_readable_reason
    REASONS[reason] || 'No reason provided'
  end
end

