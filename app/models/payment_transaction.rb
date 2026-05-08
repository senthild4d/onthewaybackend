class PaymentTransaction < ApplicationRecord
  # Associations
  belongs_to :wallet
  belongs_to :user
  belongs_to :reference, polymorphic: true, optional: true

  # Enums
  enum :transaction_type, {
    deposit: 'deposit',
    withdrawal: 'withdrawal',
    payment: 'payment',
    refund: 'refund',
    transfer: 'transfer'
  }, prefix: true

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled',
    refunded: 'refunded'
  }, prefix: true

  enum :payment_method, {
    credit_card: 'credit_card',
    debit_card: 'debit_card',
    bank_transfer: 'bank_transfer',
    crypto: 'crypto',
    paypal: 'paypal',
    apple_pay: 'apple_pay',
    google_pay: 'google_pay',
    other: 'other'
  }, prefix: true

  # Validations
  validates :wallet_id, presence: true
  validates :user_id, presence: true
  validates :transaction_type, presence: true, inclusion: { in: transaction_types.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, length: { maximum: 10 }
  validates :payment_method, presence: true, inclusion: { in: payment_methods.keys }
  validates :fee, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :net_amount, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }
  scope :completed, -> { where(status: 'completed') }
  scope :pending_or_processing, -> { where(status: ['pending', 'processing']) }

  # Callbacks
  before_validation :calculate_net_amount, :normalize_currency
  after_update :update_wallet_balance, if: :saved_change_to_status?

  def complete!
    return false unless status_pending? || status_processing?

    update!(
      status: 'completed',
      processed_at: Time.current
    )
  end

  def fail!(reason = nil)
    return false unless status_pending? || status_processing?

    update!(
      status: 'failed',
      processed_at: Time.current,
      description: [description, reason].compact.join(' - ')
    )
  end

  def cancel!
    return false unless status_pending?

    update!(
      status: 'cancelled',
      processed_at: Time.current
    )
  end

  def refund!
    return false unless status_completed?

    update!(
      status: 'refunded',
      processed_at: Time.current
    )
  end

  def metadata_hash
    return {} if metadata.blank?

    JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def provider_response_hash
    return {} if provider_response.blank?

    JSON.parse(provider_response)
  rescue JSON::ParserError
    {}
  end

  private

  def calculate_net_amount
    self.net_amount = amount - fee
  end

  def normalize_currency
    self.currency = currency&.upcase
  end

  def update_wallet_balance
    return unless status_completed?
    return if status_before_last_save == 'completed' # Already processed

    case transaction_type
    when 'deposit', 'refund'
      wallet.credit(net_amount)
    when 'withdrawal', 'payment'
      wallet.debit(amount)
    end
  end
end

