class PromoCode < ApplicationRecord
  DISCOUNT_TYPES = %w[percentage fixed].freeze

  belongs_to :event, optional: true
  belongs_to :venue, optional: true
  has_many :bookings, dependent: :nullify

  validates :code, presence: true, uniqueness: true
  validates :label, presence: true
  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, numericality: { greater_than: 0 }
  validates :currency, presence: true, if: -> { discount_type == 'fixed' }
  validates :max_uses, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validate :percentage_limits
  validate :ends_after_starts
  validate :scope_exclusive

  before_validation :normalize_code

  scope :active, -> { where(is_active: true) }

  def usable?(event: nil, venue: nil)
    return false unless is_active
    return false if starts_at.present? && Time.current < starts_at
    return false if ends_at.present? && Time.current > ends_at
    return false if max_uses.present? && uses_count.to_i >= max_uses
    if event_id.present?
      return false if event.nil? || event_id != event.id
    end
    if venue_id.present?
      return false if venue.nil? || venue_id != venue.id
    end

    true
  end

  def apply_to(amount)
    return 0.0 if amount.to_f <= 0

    if discount_type == 'percentage'
      (amount.to_f * (discount_value.to_f / 100.0)).round(2)
    else
      [discount_value.to_f, amount.to_f].min
    end
  end

  def increment_uses!
    update!(uses_count: uses_count.to_i + 1)
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def percentage_limits
    return unless discount_type == 'percentage'

    if discount_value.to_f > 100
      errors.add(:discount_value, 'must be <= 100 for percentage discounts')
    end
  end

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    if ends_at <= starts_at
      errors.add(:ends_at, 'must be after starts_at')
    end
  end

  def scope_exclusive
    return unless event_id.present? && venue_id.present?

    errors.add(:base, 'Promo code cannot be scoped to both event and venue')
  end
end
