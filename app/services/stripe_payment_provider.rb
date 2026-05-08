class StripePaymentProvider < BasePaymentProvider
  require 'stripe'

  def initialize(config)
    super(config)
    Stripe.api_key = secret_key
  end

  def process_payment(amount:, currency:, payment_method:, transaction_id:, metadata: {})
    # Use Payment Intents API (modern Stripe approach)
    amount_cents = (amount * 100).to_i

    payment_intent = Stripe::PaymentIntent.create(
      amount: amount_cents,
      currency: currency.downcase,
      payment_method: payment_method,
      description: "Payment for transaction #{transaction_id}",
      metadata: metadata.merge(transaction_id: transaction_id),
      confirm: true,
      return_url: metadata[:return_url] || nil
    )

    {
      transaction_id: payment_intent.id,
      status: payment_intent.status,
      amount: amount,
      currency: currency,
      provider: 'stripe',
      client_secret: payment_intent.client_secret
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end

  # Create a Payment Intent (for Flutter integration)
  def create_payment_intent(amount:, currency:, transaction_id:, metadata: {}, customer_id: nil, payment_method_id: nil)
    amount_cents = (amount * 100).to_i

    params = {
      amount: amount_cents,
      currency: currency.downcase,
      description: "Payment for transaction #{transaction_id}",
      metadata: metadata.merge(transaction_id: transaction_id),
      automatic_payment_methods: {
        enabled: true
      }
    }

    params[:customer] = customer_id if customer_id.present?
    params[:payment_method] = payment_method_id if payment_method_id.present?

    payment_intent = Stripe::PaymentIntent.create(params)

    {
      payment_intent_id: payment_intent.id,
      client_secret: payment_intent.client_secret,
      status: payment_intent.status,
      amount: amount,
      currency: currency
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end

  # Confirm a Payment Intent (called after Flutter confirms payment)
  def confirm_payment_intent(payment_intent_id:, payment_method_id: nil, return_url: nil)
    params = {}
    params[:payment_method] = payment_method_id if payment_method_id.present?
    params[:return_url] = return_url if return_url.present?

    payment_intent = Stripe::PaymentIntent.confirm(payment_intent_id, params)

    {
      payment_intent_id: payment_intent.id,
      status: payment_intent.status,
      amount: payment_intent.amount / 100.0,
      currency: payment_intent.currency.upcase
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end

  # Retrieve Payment Intent status
  def retrieve_payment_intent(payment_intent_id:)
    payment_intent = Stripe::PaymentIntent.retrieve(payment_intent_id)

    {
      payment_intent_id: payment_intent.id,
      status: payment_intent.status,
      amount: payment_intent.amount / 100.0,
      currency: payment_intent.currency.upcase,
      client_secret: payment_intent.client_secret
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end

  def process_deposit(amount:, currency:, payment_method:, transaction_id:, metadata: {})
    # For deposits, create a payment intent
    amount_cents = (amount * 100).to_i

    payment_intent = Stripe::PaymentIntent.create(
      amount: amount_cents,
      currency: currency.downcase,
      payment_method: payment_method,
      description: "Deposit for transaction #{transaction_id}",
      metadata: metadata.merge(transaction_id: transaction_id),
      confirm: true
    )

    {
      transaction_id: payment_intent.id,
      status: payment_intent.status,
      amount: amount,
      currency: currency,
      provider: 'stripe'
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end

  def process_withdrawal(amount:, currency:, payment_method:, destination:, transaction_id:, metadata: {})
    # For withdrawals, create a transfer or payout
    amount_cents = (amount * 100).to_i

    transfer = Stripe::Transfer.create(
      amount: amount_cents,
      currency: currency.downcase,
      destination: destination, # Bank account or external account ID
      description: "Withdrawal for transaction #{transaction_id}",
      metadata: metadata.merge(transaction_id: transaction_id)
    )

    {
      transaction_id: transfer.id,
      status: transfer.status,
      amount: amount,
      currency: currency,
      provider: 'stripe'
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end

  def process_refund(original_transaction_id:, amount:, reason: nil, transaction_id:)
    amount_cents = (amount * 100).to_i

    # Try to retrieve payment intent first
    payment_intent = Stripe::PaymentIntent.retrieve(original_transaction_id) rescue nil
    
    if payment_intent && payment_intent.charges.data.any?
      # Use the charge ID from payment intent
      charge_id = payment_intent.charges.data.first.id
    else
      # Fallback to using original_transaction_id as charge ID
      charge_id = original_transaction_id
    end

    refund = Stripe::Refund.create(
      charge: charge_id,
      amount: amount_cents,
      reason: reason || 'requested_by_customer',
      metadata: { refund_transaction_id: transaction_id }
    )

    {
      transaction_id: refund.id,
      status: refund.status,
      amount: amount,
      provider: 'stripe'
    }
  rescue Stripe::StripeError => e
    raise PaymentService::PaymentError, "Stripe error: #{e.message}"
  end
end

