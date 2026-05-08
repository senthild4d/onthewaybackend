module Api
  module V1
    class WebhooksController < ActionController::API
      include ApiResponse

      # POST /api/v1/webhooks/stripe
      def stripe
        # Stripe signs the *raw* request payload. Use raw_post to avoid issues where
        # the request body has already been consumed by middleware/parameter parsing.
        payload = request.raw_post
        sig_header = request.headers['Stripe-Signature']
        provider_secret = PaymentProvider.find_by(provider_type: 'stripe', status: 'active')&.webhook_secret.presence
        env_secret = ENV['STRIPE_WEBHOOK_SECRET'].presence
        endpoint_secret = provider_secret || env_secret
        endpoint_secret_source = provider_secret ? 'payment_providers.webhook_secret' : (env_secret ? 'ENV[STRIPE_WEBHOOK_SECRET]' : 'none')

        if endpoint_secret.blank?
          Rails.logger.error('[Stripe Webhook] Missing webhook_secret on active PaymentProvider(stripe).')
          render json: { error: 'Stripe webhook secret not configured on server' }, status: 500
          return
        end

        if sig_header.blank?
          Rails.logger.warn('[Stripe Webhook] Missing Stripe-Signature header.')
          render json: { error: 'Missing Stripe-Signature header' }, status: 400
          return
        end

        begin
          event = Stripe::Webhook.construct_event(
            payload, sig_header, endpoint_secret
          )
        rescue JSON::ParserError => e
          Rails.logger.warn("[Stripe Webhook] Invalid payload: #{e.message}")
          render json: { error: 'Invalid payload' }, status: 400
          return
        rescue Stripe::SignatureVerificationError => e
          Rails.logger.warn(
            "[Stripe Webhook] Invalid signature: #{e.message} " \
            "(payload_bytes=#{payload.to_s.bytesize}, signature_header_present=#{sig_header.present?}, secret_source=#{endpoint_secret_source})"
          )
          render json: { error: 'Invalid signature' }, status: 400
          return
        end

        # Handle the event
        case event.type
        when 'payment_intent.succeeded'
          handle_stripe_payment_succeeded(event.data.object)
        when 'payment_intent.payment_failed'
          handle_stripe_payment_failed(event.data.object)
        when 'payment_intent.requires_action'
          handle_stripe_payment_requires_action(event.data.object)
        when 'charge.succeeded'
          handle_stripe_charge_succeeded(event.data.object)
        when 'charge.refunded'
          handle_stripe_refund(event.data.object)
        when 'transfer.created'
          handle_stripe_transfer_created(event.data.object)
        else
          Rails.logger.info "Unhandled Stripe event type: #{event.type}"
        end

        render json: { received: true }, status: 200
      end

      # POST /api/v1/webhooks/paypal
      def paypal
        # PayPal webhook verification
        headers = request.headers.to_h
        body = request.body.read

        # Verify webhook signature with PayPal
        # This is a simplified version - implement proper verification
        event = JSON.parse(body)

        case event['event_type']
        when 'PAYMENT.SALE.COMPLETED'
          handle_paypal_payment_completed(event['resource'])
        when 'PAYMENT.SALE.REFUNDED'
          handle_paypal_refund(event['resource'])
        when 'PAYOUTS.PAYOUT.COMPLETED'
          handle_paypal_payout_completed(event['resource'])
        else
          Rails.logger.info "Unhandled PayPal event type: #{event['event_type']}"
        end

        render json: { received: true }, status: 200
      end

      # POST /api/v1/webhooks/crypto
      def crypto
        # Crypto webhook handler for blockchain confirmations
        payload = JSON.parse(request.body.read)

        case payload['event_type']
        when 'transaction.confirmed'
          handle_crypto_transaction_confirmed(payload)
        when 'transaction.failed'
          handle_crypto_transaction_failed(payload)
        else
          Rails.logger.info "Unhandled crypto event type: #{payload['event_type']}"
        end

        render json: { received: true }, status: 200
      end

      private

      def verify_webhook_signature
        # Skip CSRF for webhook endpoints
        true
      end

      def handle_stripe_payment_succeeded(payment_intent)
        transaction = PaymentTransaction.find_by(provider_transaction_id: payment_intent.id)
        return unless transaction

        transaction.update!(
          status: 'completed',
          provider_response: payment_intent.to_json,
          processed_at: Time.current
        )

        # Update booking if this payment is for a booking
        if transaction.reference_type == 'Booking' && transaction.reference_id
          booking = Booking.find_by(id: transaction.reference_id)
          if booking
            # Get payment type from metadata
            metadata = transaction.metadata_hash
            payment_type = metadata['payment_type'] || 'full'
            payment_amount = transaction.amount.to_d
            
            # Add payment to booking (handles partial/full/overpayment)
            booking.mark_as_paid!(transaction, amount: payment_amount)

            # Paid events: notify venue for RSVP approve/reject (venue must confirm booking)
            if booking.fully_paid? && booking.status_created?
              BookingNotificationService.notify_venue_for_booking_request(booking)
            end

            # Real-time: notify subscribed clients (e.g. Flutter app)
            BookingBroadcaster.payment_completed(booking, amount: payment_amount)
          end
        end

        # Update split and notify if this payment is for a food/bar order split (BillSplit)
        if transaction.reference_type == 'BillSplit' && transaction.reference_id
          split = BillSplit.find_by(id: transaction.reference_id)
          if split && split.payment_status_pending?
            split.mark_as_paid!(transaction)
            order = split.food_bar_order
            OrderBroadcaster.split_paid(order, split: split, amount: transaction.amount.to_f)
            OrderBroadcaster.order_fully_paid(order) if order.reload.payment_status_paid?
          end
        end
      end

      def handle_stripe_payment_failed(payment_intent)
        transaction = PaymentTransaction.find_by(provider_transaction_id: payment_intent.id)
        return unless transaction

        transaction.update!(
          status: 'failed',
          description: payment_intent.last_payment_error&.message || 'Payment failed',
          provider_response: payment_intent.to_json,
          processed_at: Time.current
        )

        # Update booking if this payment is for a booking
        if transaction.reference_type == 'Booking' && transaction.reference_id
          booking = Booking.find_by(id: transaction.reference_id)
          if booking
            # Payment failed, but don't change status if already partially paid
            # Only mark as failed if it was pending
            if booking.payment_status_pending?
              booking.mark_payment_failed!
              BookingBroadcaster.payment_failed(booking)
            end
          end
        end

        # Notify if this failed payment was for a food/bar order split (BillSplit)
        if transaction.reference_type == 'BillSplit' && transaction.reference_id
          split = BillSplit.find_by(id: transaction.reference_id)
          if split && split.payment_status_pending?
            split.mark_as_failed!
            OrderBroadcaster.split_payment_failed(split.food_bar_order, split: split)
          end
        end
      end

      def handle_stripe_payment_requires_action(payment_intent)
        transaction = PaymentTransaction.find_by(provider_transaction_id: payment_intent.id)
        return unless transaction

        transaction.update!(
          status: 'processing',
          description: 'Payment requires additional action',
          provider_response: payment_intent.to_json
        )
      end

      def handle_stripe_charge_succeeded(charge)
        transaction = PaymentTransaction.find_by(provider_transaction_id: charge.id)
        return unless transaction

        transaction.update!(
          status: 'completed',
          provider_response: charge.to_json,
          processed_at: Time.current
        )
      end

      def handle_stripe_refund(refund)
        # Find original transaction
        original_transaction = PaymentTransaction.find_by(provider_transaction_id: refund.charge)
        return unless original_transaction

        # Create or update refund transaction
        refund_transaction = PaymentTransaction.find_or_initialize_by(
          provider_transaction_id: refund.id
        )

        refund_transaction.update!(
          wallet: original_transaction.wallet,
          user: original_transaction.user,
          transaction_type: 'refund',
          status: 'completed',
          amount: refund.amount / 100.0,
          currency: refund.currency.upcase,
          payment_method: original_transaction.payment_method,
          payment_provider: 'stripe',
          reference: original_transaction,
          fee: 0,
          net_amount: refund.amount / 100.0,
          provider_response: refund.to_json,
          processed_at: Time.current
        )
      end

      def handle_stripe_transfer_created(transfer)
        transaction = PaymentTransaction.find_by(provider_transaction_id: transfer.id)
        return unless transaction

        transaction.update!(
          status: 'completed',
          provider_response: transfer.to_json,
          processed_at: Time.current
        )
      end

      def handle_paypal_payment_completed(resource)
        transaction = PaymentTransaction.find_by(provider_transaction_id: resource['id'])
        return unless transaction

        transaction.update!(
          status: 'completed',
          provider_response: resource.to_json,
          processed_at: Time.current
        )
      end

      def handle_paypal_refund(resource)
        original_transaction = PaymentTransaction.find_by(provider_transaction_id: resource['sale_id'])
        return unless original_transaction

        refund_transaction = PaymentTransaction.find_or_initialize_by(
          provider_transaction_id: resource['id']
        )

        refund_transaction.update!(
          wallet: original_transaction.wallet,
          user: original_transaction.user,
          transaction_type: 'refund',
          status: 'completed',
          amount: resource['amount']['total'].to_f,
          currency: resource['amount']['currency'].upcase,
          payment_method: original_transaction.payment_method,
          payment_provider: 'paypal',
          reference: original_transaction,
          fee: 0,
          net_amount: resource['amount']['total'].to_f,
          provider_response: resource.to_json,
          processed_at: Time.current
        )
      end

      def handle_paypal_payout_completed(resource)
        transaction = PaymentTransaction.find_by(provider_transaction_id: resource['batch_header']['payout_batch_id'])
        return unless transaction

        transaction.update!(
          status: 'completed',
          provider_response: resource.to_json,
          processed_at: Time.current
        )
      end

      def handle_crypto_transaction_confirmed(payload)
        transaction = PaymentTransaction.find_by(provider_transaction_id: payload['transaction_id'])
        return unless transaction

        transaction.update!(
          status: 'completed',
          provider_response: payload.to_json,
          processed_at: Time.current
        )
      end

      def handle_crypto_transaction_failed(payload)
        transaction = PaymentTransaction.find_by(provider_transaction_id: payload['transaction_id'])
        return unless transaction

        transaction.update!(
          status: 'failed',
          description: payload['error_message'] || 'Transaction failed',
          provider_response: payload.to_json,
          processed_at: Time.current
        )
      end
    end
  end
end

