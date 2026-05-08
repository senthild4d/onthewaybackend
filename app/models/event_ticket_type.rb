# frozen_string_literal: true

class EventTicketType < ApplicationRecord
  belongs_to :event
  has_many :booking_ticket_lines, dependent: :restrict_with_error
  has_many :ticket_entitlements, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 120 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity_total, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity_sold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :sold_not_exceed_total

  def quantity_available
    quantity_total - quantity_sold
  end

  def reserve!(qty)
    raise ArgumentError, 'qty must be positive' if qty.to_i <= 0
    with_lock do
      reload
      raise ActiveRecord::RecordInvalid, self if quantity_available < qty
      increment!(:quantity_sold, qty)
    end
  end

  def release!(qty)
    return if qty.to_i <= 0
    with_lock do
      reload
      dec = [qty, quantity_sold].min
      decrement!(:quantity_sold, dec) if dec.positive?
    end
  end

  private

  def sold_not_exceed_total
    return if quantity_sold.nil? || quantity_total.nil?
    errors.add(:quantity_sold, 'cannot exceed quantity_total') if quantity_sold > quantity_total
  end
end
