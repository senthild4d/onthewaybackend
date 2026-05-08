# frozen_string_literal: true

class VenuePrPartnership < ApplicationRecord
  ROLES = %w[master_pr junior_pr].freeze
  STATUSES = %w[active ended].freeze

  belongs_to :venue
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :venue_has_at_most_one_active_master, on: :create

  scope :active, -> { where(status: 'active') }
  scope :ended, -> { where(status: 'ended') }
  scope :master_pr, -> { where(role: 'master_pr') }
  scope :junior_pr, -> { where(role: 'junior_pr') }
  scope :active_master, -> { active.master_pr }
  scope :active_junior, -> { active.junior_pr }

  def end_partnership!
    update!(status: 'ended', ended_at: Time.current)
  end

  private

  def venue_has_at_most_one_active_master
    return unless venue_id.present? && status == 'active' && role == 'master_pr'

    if VenuePrPartnership.where(venue_id: venue_id).active_master.exists?
      errors.add(:venue_id, 'already has an active master PR')
    end
  end
end
