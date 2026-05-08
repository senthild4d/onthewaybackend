class Wallet < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :payment_transactions, dependent: :restrict_with_error

  # Enums
  enum :status, { active: 'active', suspended: 'suspended', closed: 'closed' }, prefix: true

  # Validations
  validates :user_id, presence: true
  validates :currency, presence: true, length: { maximum: 10 }
  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :locked_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :currency, uniqueness: { scope: :user_id, message: "wallet already exists for this currency" }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_currency, ->(currency) { where(currency: currency.upcase) }

  # Callbacks
  before_validation :normalize_currency

  def available_balance
    balance - locked_balance
  end

  def can_withdraw?(amount)
    available_balance >= amount.to_d
  end

  def lock_balance(amount)
    return false unless can_withdraw?(amount)

    increment!(:locked_balance, amount.to_d)
    true
  end

  def unlock_balance(amount)
    return false if locked_balance < amount.to_d

    decrement!(:locked_balance, amount.to_d)
    true
  end

  def credit(amount)
    increment!(:balance, amount.to_d)
  end

  def debit(amount)
    return false unless can_withdraw?(amount)

    decrement!(:balance, amount.to_d)
    true
  end

  def total_balance
    balance
  end

  private

  def normalize_currency
    self.currency = currency&.upcase
  end
end

