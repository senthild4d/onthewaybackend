class BasePaymentProvider
  attr_reader :config

  def initialize(config)
    @config = config
  end

  # Process a payment
  def process_payment(amount:, currency:, payment_method:, transaction_id:, metadata: {})
    raise NotImplementedError, "Subclasses must implement process_payment"
  end

  # Process a deposit
  def process_deposit(amount:, currency:, payment_method:, transaction_id:, metadata: {})
    raise NotImplementedError, "Subclasses must implement process_deposit"
  end

  # Process a withdrawal
  def process_withdrawal(amount:, currency:, payment_method:, destination:, transaction_id:, metadata: {})
    raise NotImplementedError, "Subclasses must implement process_withdrawal"
  end

  # Process a refund
  def process_refund(original_transaction_id:, amount:, reason: nil, transaction_id:)
    raise NotImplementedError, "Subclasses must implement process_refund"
  end

  protected

  def api_key
    config.api_key
  end

  def secret_key
    config.secret_key
  end

  def webhook_secret
    config.webhook_secret
  end
end

