# frozen_string_literal: true

class TicketEntitlement < ApplicationRecord
  belongs_to :booking
  belongs_to :event_ticket_type
  belongs_to :purchaser, class_name: 'User', foreign_key: 'purchaser_id', optional: false
  belongs_to :holder, class_name: 'User', foreign_key: 'holder_id', optional: true

  STATUSES = %w[pending_payment active checked_in canceled].freeze

  enum :status, {
    pending_payment: 'pending_payment',
    active: 'active',
    checked_in: 'checked_in',
    canceled: 'canceled'
  }, prefix: true

  validates :qr_token, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :ensure_qr_token, on: :create

  scope :for_holder, ->(user) { where(holder_id: user.id).or(where(purchaser_id: user.id)) }

  def activate_after_payment!
    update!(status: 'active') if status_pending_payment?
  end

  def check_in!
    update!(status: 'checked_in', checked_in_at: Time.current) if status_active?
  end

  private

  def ensure_qr_token
    self.qr_token ||= SecureRandom.urlsafe_base64(32)
  end
end
