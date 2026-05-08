class PaymentService
  class PaymentError < StandardError; end
  class InsufficientFundsError < PaymentError; end
  class InvalidProviderError < PaymentError; end

  def initialize(user, provider_name = nil)
    @user = user
    @provider_name = provider_name || default_provider_name
    @provider = load_provider
  end

  # Process a payment
  def process_payment(amount:, currency: 'USD', payment_method:, reference: nil, metadata: {})
    wallet = find_or_create_wallet(currency)
    
    transaction = PaymentTransaction.create!(
      wallet: wallet,
      user: user,
      transaction_type: 'payment',
      status: 'pending',
      amount: amount,
      currency: currency,
      payment_method: payment_method,
      payment_provider: provider_name,
      reference: reference,
      metadata: metadata.to_json,
      fee: calculate_fee(amount, payment_method),
      net_amount: amount - calculate_fee(amount, payment_method)
    )

    begin
      result = provider.process_payment(
        amount: amount,
        currency: currency,
        payment_method: payment_method,
        transaction_id: transaction.id,
        metadata: metadata
      )

      transaction.update!(
        status: 'completed',
        provider_transaction_id: result[:transaction_id],
        provider_response: result.to_json,
        processed_at: Time.current
      )

      # Wallet balance updated via PaymentTransaction callback

      { success: true, transaction: transaction, result: result }
    rescue => e
      transaction.update!(
        status: 'failed',
        description: e.message,
        processed_at: Time.current
      )
      { success: false, transaction: transaction, error: e.message }
    end
  end

  # Process a deposit
  def process_deposit(amount:, currency: 'USD', payment_method:, metadata: {})
    wallet = find_or_create_wallet(currency)
    
    transaction = PaymentTransaction.create!(
      wallet: wallet,
      user: user,
      transaction_type: 'deposit',
      status: 'pending',
      amount: amount,
      currency: currency,
      payment_method: payment_method,
      payment_provider: provider_name,
      metadata: metadata.to_json,
      fee: calculate_fee(amount, payment_method),
      net_amount: amount - calculate_fee(amount, payment_method)
    )

    begin
      result = provider.process_deposit(
        amount: amount,
        currency: currency,
        payment_method: payment_method,
        transaction_id: transaction.id,
        metadata: metadata
      )

      transaction.update!(
        status: 'completed',
        provider_transaction_id: result[:transaction_id],
        provider_response: result.to_json,
        processed_at: Time.current
      )

      # Wallet balance updated via PaymentTransaction callback

      { success: true, transaction: transaction, result: result }
    rescue => e
      transaction.update!(
        status: 'failed',
        description: e.message,
        processed_at: Time.current
      )
      { success: false, transaction: transaction, error: e.message }
    end
  end

  # Process a withdrawal
  def process_withdrawal(amount:, currency: 'USD', payment_method:, destination:, metadata: {})
    wallet = find_or_create_wallet(currency)
    
    raise InsufficientFundsError, "Insufficient funds" unless wallet.can_withdraw?(amount)

    transaction = PaymentTransaction.create!(
      wallet: wallet,
      user: user,
      transaction_type: 'withdrawal',
      status: 'pending',
      amount: amount,
      currency: currency,
      payment_method: payment_method,
      payment_provider: provider_name,
      metadata: metadata.merge(destination: destination).to_json,
      fee: calculate_fee(amount, payment_method),
      net_amount: amount - calculate_fee(amount, payment_method)
    )

    # Lock the balance
    wallet.lock_balance(amount)

    begin
      result = provider.process_withdrawal(
        amount: amount,
        currency: currency,
        payment_method: payment_method,
        destination: destination,
        transaction_id: transaction.id,
        metadata: metadata
      )

      transaction.update!(
        status: 'completed',
        provider_transaction_id: result[:transaction_id],
        provider_response: result.to_json,
        processed_at: Time.current
      )

      # Unlock balance (wallet debit handled by callback)
      wallet.unlock_balance(amount)

      { success: true, transaction: transaction, result: result }
    rescue => e
      transaction.update!(
        status: 'failed',
        description: e.message,
        processed_at: Time.current
      )
      wallet.unlock_balance(amount)
      { success: false, transaction: transaction, error: e.message }
    end
  end

  # Process a refund
  def process_refund(original_transaction:, amount: nil, reason: nil)
    amount ||= original_transaction.amount
    wallet = original_transaction.wallet

    transaction = PaymentTransaction.create!(
      wallet: wallet,
      user: user,
      transaction_type: 'refund',
      status: 'pending',
      amount: amount,
      currency: original_transaction.currency,
      payment_method: original_transaction.payment_method,
      payment_provider: original_transaction.payment_provider,
      reference: original_transaction,
      description: reason,
      fee: 0,
      net_amount: amount
    )

    begin
      result = provider.process_refund(
        original_transaction_id: original_transaction.provider_transaction_id,
        amount: amount,
        reason: reason,
        transaction_id: transaction.id
      )

      transaction.update!(
        status: 'completed',
        provider_transaction_id: result[:transaction_id],
        provider_response: result.to_json,
        processed_at: Time.current
      )

      # Wallet balance updated via PaymentTransaction callback

      { success: true, transaction: transaction, result: result }
    rescue => e
      transaction.update!(
        status: 'failed',
        description: e.message,
        processed_at: Time.current
      )
      { success: false, transaction: transaction, error: e.message }
    end
  end

  private

  attr_reader :user, :provider_name, :provider

  def default_provider_name
    PaymentProvider.default.first&.name || 'stripe'
  end

  def load_provider
    provider_config = PaymentProvider.active_lookup(provider_name)
    raise InvalidProviderError, "Provider #{provider_name} not found or inactive" unless provider_config

    case provider_config.provider_type
    when 'stripe'
      StripePaymentProvider.new(provider_config)
    when 'paypal'
      PaypalPaymentProvider.new(provider_config)
    when 'crypto'
      CryptoPaymentProvider.new(provider_config)
    else
      raise InvalidProviderError, "Unsupported provider type: #{provider_config.provider_type}"
    end
  end

  def find_or_create_wallet(currency)
    user.wallets.find_or_create_by!(currency: currency) do |wallet|
      wallet.status = 'active'
      wallet.balance = 0
      wallet.locked_balance = 0
    end
  end

  def calculate_fee(amount, payment_method)
    # Default fee calculation - can be customized per provider
    case payment_method
    when 'credit_card', 'debit_card'
      (amount * 0.029) + 0.30 # 2.9% + $0.30
    when 'crypto'
      amount * 0.01 # 1%
    when 'paypal'
      amount * 0.034 + 0.30 # 3.4% + $0.30
    else
      0
    end
  end
end

