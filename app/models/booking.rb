class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :payment_transaction, optional: true
  has_many :payment_transactions, as: :reference, dependent: :nullify, class_name: 'PaymentTransaction'
  belongs_to :promo_code, optional: true
  belongs_to :cancellation_approved_by, class_name: 'User', optional: true
  belongs_to :assigned_pr_user, class_name: 'User', optional: true
  belongs_to :assigned_pr_assigned_by, class_name: 'User', optional: true
  has_one :vibe_check, dependent: :nullify
  has_many :food_bar_orders, dependent: :nullify
  has_many :booking_ticket_lines, dependent: :destroy
  has_many :ticket_entitlements, dependent: :destroy
  
  EXPIRY_MINUTES = 10

  after_create :set_expiry_at
  after_commit :activate_ticket_entitlements_after_payment, on: [:update]
  after_commit :release_ticket_inventory_on_cancel, on: [:update]

  # Validations
  validates :status, presence: true, inclusion: { in: %w[created confirmed canceled checked_in] }
  validate :max_bookings_per_user_for_event
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :adults_count, :children_count, :infants_count, :pets_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0
  }
  validates :adults_count, numericality: { less_than_or_equal_to: 10 }
  validates :payment_status, presence: true, inclusion: { in: %w[pending partial paid failed refunded] }
  validates :paid_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :paid_amount_not_exceeding_price
  validate :event_not_past
  validate :event_not_canceled
  validate :payment_required_for_paid_events
  
  # Enums
  enum :status, { created: 'created', confirmed: 'confirmed', canceled: 'canceled', checked_in: 'checked_in' }, prefix: true
  enum :payment_status, { pending: 'pending', partial: 'partial', paid: 'paid', failed: 'failed', refunded: 'refunded' }, prefix: true
  
  # Scopes
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :created, -> { where(status: 'created') }
  scope :canceled, -> { where(status: 'canceled') }
  scope :checked_in, -> { where(status: 'checked_in') }
  scope :upcoming, -> { joins(:event).where('events.starts_at > ?', Time.current) }
  scope :past, -> { joins(:event).where('events.ends_at < ?', Time.current) }
  scope :paid, -> { where(payment_status: ['paid', 'partial']) }
  scope :fully_paid, -> { where(payment_status: 'paid') }
  scope :partially_paid, -> { where(payment_status: 'partial') }
  scope :pending_payment, -> { where(payment_status: 'pending') }
  scope :free, -> { where(price: 0) }
  scope :paid_events, -> { where('price > 0') }
  # Bookings that currently hold a table (not canceled, have table_number)
  scope :occupying_table, -> { where.not(table_number: nil).where(status: %w[created confirmed checked_in]) }

  # Hide unpaid bookings that passed their hold window (still `created`, not yet cleaned up).
  scope :visible_in_listings, lambda {
    where(
      "bookings.status != 'created' OR bookings.expiry_at IS NULL OR bookings.expiry_at > ?",
      Time.current
    )
  }

  # True if the given table is already assigned to another booking for this event.
  def self.table_occupied_for_event?(event_id, table_number, exclude_booking_id: nil)
    return false if table_number.blank?
    rel = occupying_table.where(event_id: event_id, table_number: table_number.to_s.strip)
    rel = rel.where.not(id: exclude_booking_id) if exclude_booking_id.present?
    rel.exists?
  end

  # Methods
  def check_in!
    update!(
      status: 'checked_in',
      checked_in_at: Time.current
    )
  end

  # Free the table when the guest leaves so the table can be reused.
  def check_out!
    update!(
      table_number: nil,
      assigned_by_id: nil,
      table_assigned_at: nil
    )
  end

  def request_cancellation!(reason: nil)
    update!(
      cancellation_requested: true,
      cancellation_requested_at: Time.current,
      cancellation_reason: reason
    )
  end
  
  def approve_cancellation!(approved_by:)
    update!(
      cancellation_approved: true,
      cancellation_approved_by: approved_by,
      cancellation_approved_at: Time.current,
      status: 'canceled',
      canceled_at: Time.current
    )
    
    # Process refund if paid
    process_refund if payment_status_paid?
  end
  
  def reject_cancellation!(rejected_reason:, approved_by:)
    update!(
      cancellation_requested: false,
      cancellation_approved: false,
      cancellation_approved_by: approved_by,
      cancellation_rejected_reason: rejected_reason
    )
  end
  
  def cancel!
    # Direct cancel (without approval)
    update!(status: 'canceled', canceled_at: Time.current)
    # Process refund if paid
    process_refund if payment_status_paid?
  end
  
  def pending_cancellation?
    cancellation_requested? && cancellation_approved.nil?
  end
  
  def can_cancel?
    (status_created? || status_confirmed?) && event.present? && event.is_upcoming?
  end
  
  def cancellation_refund_amount
    return 0 unless payment_status_paid?
    event.calculate_cancellation_refund(price)
  end
  
  def cancellation_fee_amount
    return 0 unless payment_status_paid?
    event.calculate_cancellation_fee(price)
  end
  
  def cancellation_info
    return nil unless can_cancel?
    
    {
      can_cancel: true,
      refund_amount: cancellation_refund_amount.to_f,
      cancellation_fee: cancellation_fee_amount.to_f,
      original_price: price.to_f,
      currency: currency,
      policy: event.cancellation_policy_info
    }
  end
  
  def mark_as_paid!(transaction, amount: nil)
    amount ||= transaction.amount
    
    new_paid_amount = (paid_amount || 0) + amount.to_d
    booking_price = price.to_d
    
    # Determine payment status and type
    if new_paid_amount >= booking_price
      # Full payment or overpayment
      payment_status = 'paid'
      payment_type = new_paid_amount > booking_price ? 'overpayment' : 'full'
      # Note: We allow overpayments (paid_amount can exceed price for pre-orders, etc.)
    else
      # Partial payment
      payment_status = 'partial'
      payment_type = 'partial'
    end
    
    update!(
      payment_status: payment_status,
      paid_amount: new_paid_amount,
      payment_transaction: transaction,
      payment_type: payment_type,
      paid_at: Time.current
    )

    # Once fully paid, confirm the booking.
    if payment_status == 'paid' && status_created?
      update!(status: 'confirmed', expiry_at: nil)
    end

    promo_code&.increment_uses!
  end
  
  def add_partial_payment!(transaction, amount:)
    mark_as_paid!(transaction, amount: amount)
  end
  
  def remaining_amount
    # Calculate remaining amount (can be negative for overpayments)
    remaining = price.to_d - (paid_amount || 0).to_d
    # Return 0 if fully paid or overpaid
    [remaining, 0].max
  end
  
  def fully_paid?
    payment_status_paid? && remaining_amount.zero?
  end
  
  def partially_paid?
    payment_status_partial?
  end
  
  def payment_progress_percentage
    return 100 if free? || price.zero?
    return 0 if paid_amount.zero?
    # Can exceed 100% for overpayments
    (paid_amount.to_d / price.to_d * 100).round(2)
  end
  
  def mark_payment_failed!
    update!(payment_status: 'failed')
  end
  
  def free?
    price.zero? || event.is_free?
  end

  def total_attendees_count
    (adults_count || 0) + (children_count || 0) + (infants_count || 0) + (pets_count || 0)
  end

  def ticket_booking?
    booking_ticket_lines.any?
  end

  # Returns the overall monetary value associated with this booking:
  # base booking price plus any linked pre-order food/bar orders.
  def total_price_with_preorders
    base = price.to_d
    preorder_total = food_bar_orders.sum(:total_amount)
    (base + preorder_total.to_d).to_f
  end
  
  def requires_payment?
    !free?
  end
  
  def paid?
    (payment_status_paid? || payment_status_partial?) || free?
  end
  
  def can_check_in?
    status_confirmed? && fully_paid?
  end

  # Unpaid hold expired (still `created`) — hide from listing APIs until job deletes/cancels.
  def expired_pending_hold?
    status_created? && expiry_at.present? && expiry_at < Time.current
  end

  def visible_in_listings?
    !expired_pending_hold?
  end

  # Flags for booking detail / websocket (attendance_mode, ticket window, RSVP venue switch).
  def api_flow_context
    ev = event
    return {} unless ev

    ticket_window_closed = ev.tickets_mode? && ev.tickets_closed?
    types = ev.event_ticket_types
    has_ticket_inventory = types.any? { |t| t.quantity_available.to_i.positive? }

    {
      attendance_mode: ev.attendance_mode,
      ticket_sales_window_closed: ticket_window_closed,
      venue_rsvp_notifications_enabled: ev.venue_rsvp_enabled?,
      ticket_inventory_available: has_ticket_inventory,
      suggest_standard_ticket_flow: ev.tickets_mode? && !ticket_window_closed && has_ticket_inventory,
      suggest_rsvp_or_manual_flow_when_no_ticket_inventory: ticket_window_closed && !has_ticket_inventory,
      awaiting_venue_or_pr_response: status_created?,
      is_expired_pending_hold: expired_pending_hold?,
      pr_chat_hint: 'Use POST /api/v1/chats with user_id + booking_id for a booking-scoped thread; wait for venue/PR on booking channel updates.'
    }
  end

  # Rich payload for ActionCable (aligned with booking detail fields used by apps).
  # Human-friendly approval state for APIs (venue/PR approve or guest wait).
  def venue_approval_status_label
    return 'canceled' if status_canceled?
    return 'checked_in' if status_checked_in?
    return 'pending' if status_created?
    return 'approved' if status_confirmed?
    'unknown'
  end

  def websocket_detail_payload
    reload
    ev = event
    {
      id: id,
      status: status,
      price: price.to_f,
      total_price: total_price_with_preorders,
      currency: currency,
      payment_status: payment_status,
      payment_type: payment_type,
      paid_amount: paid_amount.to_f,
      remaining_amount: remaining_amount.to_f,
      payment_progress_percentage: payment_progress_percentage,
      fully_paid: fully_paid?,
      partially_paid: partially_paid?,
      paid_at: paid_at&.iso8601,
      notes: notes,
      table_number: table_number,
      assigned_pr_user_id: assigned_pr_user_id&.to_s,
      attendees: {
        adults_count: adults_count || 0,
        children_count: children_count || 0,
        infants_count: infants_count || 0,
        pets_count: pets_count || 0,
        total_count: total_attendees_count
      },
      event: ev ? { id: ev.id, title: ev.title, attendance_mode: ev.attendance_mode, starts_at: ev.starts_at&.iso8601 } : nil,
      expiry_at: expiry_at&.iso8601,
      updated_at: updated_at.iso8601,
      venue_approval_status: venue_approval_status_label
    }.merge(api_flow_context_for_booking(ev))
  end

  # Lightweight variant of `#api_flow_context` for websocket payloads: avoids loading every
  # `event_ticket_types` row (can be hundreds) on every booking broadcast / payment update.
  def api_flow_context_for_booking(ev)
    return {} unless ev

    ticket_window_closed = ev.tickets_mode? && ev.tickets_closed?
    tts = EventTicketType.arel_table
    has_ticket_inventory =
      ev.event_ticket_types
        .where((tts[:quantity_total] - tts[:quantity_sold]).gt(0))
        .exists?

    {
      attendance_mode: ev.attendance_mode,
      ticket_sales_window_closed: ticket_window_closed,
      venue_rsvp_notifications_enabled: ev.venue_rsvp_enabled?,
      ticket_inventory_available: has_ticket_inventory,
      suggest_standard_ticket_flow: ev.tickets_mode? && !ticket_window_closed && has_ticket_inventory,
      suggest_rsvp_or_manual_flow_when_no_ticket_inventory: ticket_window_closed && !has_ticket_inventory,
      awaiting_venue_or_pr_response: status_created?,
      is_expired_pending_hold: expired_pending_hold?,
      pr_chat_hint: 'Use POST /api/v1/chats with user_id + booking_id for a booking-scoped thread; wait for venue/PR on booking channel updates.'
    }
  end

  private
  
  def process_refund
    return if free? || !payment_transaction
    
    # Calculate refund amount based on cancellation policy
    refund_amount = event.calculate_cancellation_refund(price)
    
    return if refund_amount.zero?
    
    # Create refund transaction
    refund_service = PaymentService.new(user)
    result = refund_service.process_refund(
      transaction: payment_transaction,
      amount: refund_amount,
      reason: 'Booking canceled'
    )
    
    if result[:success]
      update!(
        payment_status: 'refunded',
        refund_amount: refund_amount,
        cancellation_fee: price - refund_amount
      )
    end
  rescue => e
    Rails.logger.error "Failed to process refund for booking #{id}: #{e.message}"
    # Still mark as canceled but note refund failed
  end
  
  def event_not_past
    return unless event.present?
    
    if event.ends_at < Time.current
      errors.add(:base, 'Cannot book past events')
    end
  end

  def max_bookings_per_user_for_event
    return unless user_id.present? && event_id.present?

    existing_count = Booking.where(user_id: user_id, event_id: event_id).where.not(id: id).count
    return if existing_count < 10

    errors.add(:base, 'Maximum 10 bookings per user for this event')
  end
  
  def event_not_canceled
    return unless event.present?
    
    if event.status_canceled?
      errors.add(:base, 'Cannot book canceled events')
    end
  end
  
  def payment_required_for_paid_events
    return unless event.present?
    
    if !event.is_free? && price > 0 && payment_status_pending?
      # Payment is required but not yet paid
      # This is allowed during booking creation, but booking won't be confirmed until paid
    end
  end
  
  def paid_amount_not_exceeding_price
    return unless paid_amount.present? && price.present?
    
    # Allow overpayments (paid_amount can exceed price for pre-orders, etc.)
    # Only validate that paid_amount is not negative
    if paid_amount.to_d < 0
      errors.add(:paid_amount, "cannot be negative")
    end
  end

  def set_expiry_at
    return unless status_created?
    update_column(:expiry_at, EXPIRY_MINUTES.minutes.from_now)
  end

  def activate_ticket_entitlements_after_payment
    return unless ticket_booking?
    return unless saved_change_to_payment_status? || saved_change_to_paid_amount?
    return unless payment_status_paid? && fully_paid?
    ticket_entitlements.status_pending_payment.find_each(&:activate_after_payment!)
  end

  def release_ticket_inventory_on_cancel
    return unless ticket_booking?
    return unless saved_change_to_status? && status_canceled?
    booking_ticket_lines.each do |line|
      line.event_ticket_type.release!(line.quantity)
    end
    ticket_entitlements.where(status: %w[pending_payment active])
                       .update_all(status: 'canceled', updated_at: Time.current)
  end
end

