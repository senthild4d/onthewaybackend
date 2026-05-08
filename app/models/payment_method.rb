class PaymentMethod < ApplicationRecord
  # Associations
  belongs_to :user

  # Enums
  enum :payment_method_type, {
    credit_card: 'credit_card',
    debit_card: 'debit_card',
    bank_account: 'bank_account',
    crypto_wallet: 'crypto_wallet',
    paypal: 'paypal',
    apple_pay: 'apple_pay',
    google_pay: 'google_pay'
  }, prefix: true

  enum :status, { active: 'active', inactive: 'inactive', expired: 'expired' }, prefix: true

  # Validations
  validates :user_id, presence: true
  validates :payment_method_type, presence: true, inclusion: { in: payment_method_types.keys }
  validates :provider, presence: true
  validates :provider_payment_method_id, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :provider_payment_method_id, uniqueness: { scope: [:user_id, :provider], message: "payment method already exists" }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :by_type, ->(type) { where(payment_method_type: type) }
  scope :default, -> { where(is_default: true) }

  # Callbacks
  before_save :ensure_single_default

  def metadata_hash
    return {} if metadata.blank?

    metadata.is_a?(Hash) ? metadata : JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def billing_address_hash
    return {} if billing_address.blank?

    billing_address.is_a?(Hash) ? billing_address : JSON.parse(billing_address)
  rescue JSON::ParserError
    {}
  end

  def display_name
    case payment_method_type
    when 'credit_card', 'debit_card'
      "#{card_brand} •••• #{card_last4}"
    when 'bank_account'
      "Bank Account •••• #{card_last4 || '****'}"
    when 'crypto_wallet'
      "#{metadata_hash['crypto_currency'] || 'Crypto'} Wallet"
    when 'paypal'
      billing_email || 'PayPal Account'
    else
      payment_method_type.humanize
    end
  end

  def is_expired?
    return false unless card_exp_year.present? && card_exp_month.present?

    exp_date = Date.new(card_exp_year.to_i, card_exp_month.to_i, -1)
    exp_date < Date.today
  end

  private

  def ensure_single_default
    return unless is_default? && is_default_changed?

    user.payment_methods.where.not(id: id).update_all(is_default: false)
  end
end


