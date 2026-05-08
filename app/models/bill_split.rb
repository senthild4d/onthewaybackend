class BillSplit < ApplicationRecord
  belongs_to :food_bar_order
  belongs_to :user, optional: true
  belongs_to :payment_transaction, optional: true
  
  validates :split_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_status, presence: true, inclusion: { in: %w[pending paid failed refunded] }
  
  enum :payment_status, {
    pending: 'pending',
    paid: 'paid',
    failed: 'failed',
    refunded: 'refunded'
  }, prefix: :payment_status
  
  scope :pending, -> { where(payment_status: 'pending') }
  scope :paid, -> { where(payment_status: 'paid') }
  
  def mark_as_paid!(transaction)
    update!(
      payment_status: 'paid',
      payment_transaction: transaction,
      paid_at: Time.current
    )
    
    # Check if all splits are paid and update order
    food_bar_order.mark_as_fully_paid! if food_bar_order.all_splits_paid?
  end
  
  def mark_as_failed!
    update!(payment_status: 'failed')
  end
  
  def participant_name
    user&.name || split_name || 'Guest'
  end
end
