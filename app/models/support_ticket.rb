# frozen_string_literal: true

class SupportTicket < ApplicationRecord
  REASONS = %w[
    payment_issue
    booking_issue
    event_issue
    venue_issue
    account_issue
    bug_report
    feedback
    other
  ].freeze

  STATUSES = %w[open in_progress resolved closed].freeze
  PRIORITIES = %w[low medium high].freeze

  belongs_to :user, optional: true
  belongs_to :assigned_to, class_name: 'User', optional: true

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }

  scope :open, -> { where(status: 'open') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :closed, -> { where(status: 'closed') }
end

