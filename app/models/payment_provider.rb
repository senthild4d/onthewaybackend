class PaymentProvider < ApplicationRecord
  # Enums
  enum :provider_type, {
    stripe: 'stripe',
    paypal: 'paypal',
    crypto: 'crypto',
    bank: 'bank',
    apple_pay: 'apple_pay',
    google_pay: 'google_pay',
    other: 'other'
  }, prefix: true

  enum :status, {
    active: 'active',
    inactive: 'inactive',
    maintenance: 'maintenance'
  }, prefix: true

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :provider_type, presence: true, inclusion: { in: provider_types.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(provider_type: type) }
  scope :default, -> { where(is_default: true) }

  # Look up an active provider by provider_type (preferred) or name (fallback).
  # Accepts values like "stripe" or "Stripe".
  def self.active_lookup(key)
    return nil if key.blank?

    k = key.to_s
    active.find_by(provider_type: k) || active.find_by('lower(name) = ?', k.downcase)
  end

  # Callbacks
  before_save :ensure_single_default

  def credentials_hash
    return {} if credentials.blank?

    credentials.is_a?(Hash) ? credentials : JSON.parse(credentials)
  rescue JSON::ParserError
    {}
  end

  def settings_hash
    return {} if settings.blank?

    settings.is_a?(Hash) ? settings : JSON.parse(settings)
  rescue JSON::ParserError
    {}
  end

  def api_key
    credentials_hash['api_key'] || credentials_hash[:api_key]
  end

  def secret_key
    credentials_hash['secret_key'] || credentials_hash[:secret_key]
  end

  def webhook_secret
    credentials_hash['webhook_secret'] || credentials_hash[:webhook_secret]
  end

  private

  def ensure_single_default
    return unless is_default? && is_default_changed?

    PaymentProvider.where.not(id: id).update_all(is_default: false)
  end
end

