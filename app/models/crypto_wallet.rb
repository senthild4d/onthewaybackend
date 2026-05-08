class CryptoWallet < ApplicationRecord
  # Associations
  belongs_to :user

  # Enums
  enum :wallet_type, { external: 'external', internal: 'internal' }, prefix: true
  enum :status, { active: 'active', suspended: 'suspended', archived: 'archived' }, prefix: true

  # Validations
  validates :user_id, presence: true
  validates :crypto_currency, presence: true, inclusion: { in: %w[BTC ETH USDT USDC SOL MATIC BNB] }
  validates :wallet_address, presence: true, length: { minimum: 26, maximum: 100 }
  validates :wallet_type, presence: true, inclusion: { in: wallet_types.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :wallet_address, uniqueness: { scope: :crypto_currency, message: "address already exists for this cryptocurrency" }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_crypto, ->(crypto) { where(crypto_currency: crypto.upcase) }
  scope :external, -> { where(wallet_type: 'external') }
  scope :internal, -> { where(wallet_type: 'internal') }

  # Callbacks
  before_validation :normalize_crypto_currency, :normalize_wallet_address

  def metadata_hash
    return {} if metadata.blank?

    JSON.parse(metadata)
  rescue JSON::ParserError
    {}
  end

  def display_name
    "#{crypto_currency} Wallet"
  end

  def short_address
    return wallet_address if wallet_address.length <= 12

    "#{wallet_address[0..5]}...#{wallet_address[-4..-1]}"
  end

  private

  def normalize_crypto_currency
    self.crypto_currency = crypto_currency&.upcase
  end

  def normalize_wallet_address
    self.wallet_address = wallet_address&.strip
  end
end

