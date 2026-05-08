class PaypalPaymentProvider < BasePaymentProvider
  require 'paypal-sdk-rest'

  def initialize(config)
    super(config)
    PayPal::SDK::Core::Config.load('config/paypal.yml', Rails.env) if File.exist?('config/paypal.yml')
  end

  def process_payment(amount:, currency:, payment_method:, transaction_id:, metadata: {})
    payment = PayPal::SDK::REST::Payment.new({
      intent: 'sale',
      payer: { payment_method: 'paypal' },
      transactions: [{
        amount: {
          total: amount.to_s,
          currency: currency
        },
        description: "Payment for transaction #{transaction_id}"
      }],
      redirect_urls: {
        return_url: metadata[:return_url] || '',
        cancel_url: metadata[:cancel_url] || ''
      }
    })

    if payment.create
      {
        transaction_id: payment.id,
        status: payment.state,
        amount: amount,
        currency: currency,
        provider: 'paypal',
        approval_url: payment.links.find { |l| l.rel == 'approval_url' }&.href
      }
    else
      raise PaymentService::PaymentError, "PayPal error: #{payment.error}"
    end
  rescue => e
    raise PaymentService::PaymentError, "PayPal error: #{e.message}"
  end

  def process_deposit(amount:, currency:, payment_method:, transaction_id:, metadata: {})
    process_payment(
      amount: amount,
      currency: currency,
      payment_method: payment_method,
      transaction_id: transaction_id,
      metadata: metadata
    )
  end

  def process_withdrawal(amount:, currency:, payment_method:, destination:, transaction_id:, metadata: {})
    payout = PayPal::SDK::REST::Payout.new({
      sender_batch_header: {
        sender_batch_id: transaction_id,
        email_subject: "Withdrawal for transaction #{transaction_id}"
      },
      items: [{
        recipient_type: 'EMAIL',
        amount: {
          value: amount.to_s,
          currency: currency
        },
        receiver: destination,
        note: "Withdrawal for transaction #{transaction_id}"
      }]
    })

    if payout.create
      {
        transaction_id: payout.batch_header.payout_batch_id,
        status: payout.batch_header.batch_status,
        amount: amount,
        currency: currency,
        provider: 'paypal'
      }
    else
      raise PaymentService::PaymentError, "PayPal error: #{payout.error}"
    end
  rescue => e
    raise PaymentService::PaymentError, "PayPal error: #{e.message}"
  end

  def process_refund(original_transaction_id:, amount:, reason: nil, transaction_id:)
    sale = PayPal::SDK::REST::Sale.find(original_transaction_id)
    
    refund = sale.refund({
      amount: {
        total: amount.to_s,
        currency: sale.amount.currency
      }
    })

    if refund.success?
      {
        transaction_id: refund.id,
        status: refund.state,
        amount: amount,
        provider: 'paypal'
      }
    else
      raise PaymentService::PaymentError, "PayPal refund error: #{refund.error}"
    end
  rescue => e
    raise PaymentService::PaymentError, "PayPal error: #{e.message}"
  end
end

