module Api
  module V1
    class PaymentsController < ApplicationController
      before_action :require_authentication!

      # POST /api/v1/payments/deposit
      def deposit
        amount = params[:amount]&.to_d
        currency = params[:currency]&.upcase || 'USD'
        payment_method = params[:payment_method]
        provider = params[:provider]

        unless amount && amount > 0
          api_error(message: 'Valid amount is required', status: :bad_request)
          return
        end

        unless payment_method
          api_error(message: 'Payment method is required', status: :bad_request)
          return
        end

        payment_service = PaymentService.new(current_user, provider)
        result = payment_service.process_deposit(
          amount: amount,
          currency: currency,
          payment_method: payment_method,
          metadata: params[:metadata] || {}
        )

        if result[:success]
          api_success(
            data: {
              transaction: transaction_response(result[:transaction]),
              provider_result: result[:result]
            },
            message: 'Deposit initiated successfully',
            status: :created
          )
        else
          api_error(message: result[:error] || 'Deposit failed', status: :unprocessable_entity)
        end
      end

      # POST /api/v1/payments/withdraw
      def withdraw
        amount = params[:amount]&.to_d
        currency = params[:currency]&.upcase || 'USD'
        payment_method = params[:payment_method]
        destination = params[:destination]
        provider = params[:provider]

        unless amount && amount > 0
          api_error(message: 'Valid amount is required', status: :bad_request)
          return
        end

        unless payment_method && destination
          api_error(message: 'Payment method and destination are required', status: :bad_request)
          return
        end

        payment_service = PaymentService.new(current_user, provider)
        result = payment_service.process_withdrawal(
          amount: amount,
          currency: currency,
          payment_method: payment_method,
          destination: destination,
          metadata: params[:metadata] || {}
        )

        if result[:success]
          api_success(
            data: {
              transaction: transaction_response(result[:transaction]),
              provider_result: result[:result]
            },
            message: 'Withdrawal initiated successfully',
            status: :created
          )
        else
          api_error(message: result[:error] || 'Withdrawal failed', status: :unprocessable_entity)
        end
      end

      # POST /api/v1/payments/pay
      def pay
        amount = params[:amount]&.to_d
        currency = params[:currency]&.upcase || 'USD'
        payment_method = params[:payment_method]
        reference_type = params[:reference_type]
        reference_id = params[:reference_id]
        provider = params[:provider]

        unless amount && amount > 0
          api_error(message: 'Valid amount is required', status: :bad_request)
          return
        end

        unless payment_method
          api_error(message: 'Payment method is required', status: :bad_request)
          return
        end

        reference = nil
        if reference_type && reference_id
          reference = reference_type.constantize.find_by(id: reference_id)
          unless reference
            api_error(message: 'Reference not found', status: :not_found)
            return
          end
        end

        payment_service = PaymentService.new(current_user, provider)
        result = payment_service.process_payment(
          amount: amount,
          currency: currency,
          payment_method: payment_method,
          reference: reference,
          metadata: params[:metadata] || {}
        )

        if result[:success]
          api_success(
            data: {
              transaction: transaction_response(result[:transaction]),
              provider_result: result[:result]
            },
            message: 'Payment processed successfully',
            status: :created
          )
        else
          api_error(message: result[:error] || 'Payment failed', status: :unprocessable_entity)
        end
      end

      # POST /api/v1/payments/create_intent (for Flutter)
      def create_intent
        amount = params[:amount]&.to_d
        currency = params[:currency]&.upcase || 'USD'
        provider = params[:provider] || 'stripe'
        reference_type = params[:reference_type]
        reference_id = params[:reference_id]
        customer_id = params[:customer_id]
        payment_method_id = params[:payment_method_id]

        unless amount && amount > 0
          api_error(message: 'Valid amount is required', status: :bad_request)
          return
        end

        reference = nil
        if reference_type && reference_id
          reference = reference_type.constantize.find_by(id: reference_id)
          unless reference
            api_error(message: 'Reference not found', status: :not_found)
            return
          end
          
          # Handle booking-specific payment logic
          if reference_type == 'Booking' && reference.is_a?(Booking)
            booking = reference
            unless booking.user_id == current_user.id
              api_error(message: 'Unauthorized', status: :forbidden)
              return
            end
            
            # Validate booking can be paid
            if booking.payment_status_paid? && booking.fully_paid?
              api_error(message: 'Booking is already fully paid', status: :bad_request)
              return
            end
            
            if booking.status_canceled?
              api_error(message: 'Cannot pay for canceled booking', status: :bad_request)
              return
            end
            
            if booking.free?
              api_error(message: 'This booking is free and does not require payment', status: :bad_request)
              return
            end
            
            # Get payment type and amount
            payment_type_param = params[:payment_type] # 'pre_payment', 'partial', 'full', 'overpayment'
            booking_price = booking.price.to_d
            remaining = booking.remaining_amount
            provided_amount = amount.to_d
            
            # Determine payment type if not provided
            if payment_type_param.nil?
              if provided_amount >= remaining
                payment_type_param = provided_amount > remaining ? 'overpayment' : 'full'
              else
                payment_type_param = 'partial'
              end
            end
            
            # Validate payment type logic
            case payment_type_param
            when 'pre_payment'
              # Pre-payment: paying before full booking is confirmed (deposit)
              # Amount can be less than booking price
            when 'partial'
              if provided_amount >= remaining
                api_error(message: "Partial payment amount (#{provided_amount}) must be less than remaining amount (#{remaining})", status: :bad_request)
                return
              end
            when 'full'
              unless (provided_amount - remaining).abs <= 0.01 # Allow 1 cent tolerance
                api_error(message: "Full payment amount (#{provided_amount}) must match remaining amount (#{remaining})", status: :bad_request)
                return
              end
            when 'overpayment'
              if provided_amount <= remaining
                api_error(message: "Overpayment amount (#{provided_amount}) must be greater than remaining amount (#{remaining})", status: :bad_request)
                return
              end
            else
              api_error(message: "Invalid payment_type. Must be one of: pre_payment, partial, full, overpayment", status: :bad_request)
              return
            end
            
            # Use booking currency (ensures consistency)
            currency = booking.currency
            
            # Store payment type in metadata
            params[:metadata] ||= {}
            params[:metadata][:payment_type] = payment_type_param
            params[:metadata][:booking_price] = booking_price.to_f
            params[:metadata][:remaining_amount] = remaining.to_f
            params[:metadata][:current_paid_amount] = booking.paid_amount.to_f
          end
        end

        # Create PaymentTransaction record
        wallet = current_user.wallets.find_or_create_by!(currency: currency) do |w|
          w.status = 'active'
          w.balance = 0
          w.locked_balance = 0
        end

        # Prepare metadata
        metadata = params[:metadata] || {}
        if reference_type == 'Booking' && reference.is_a?(Booking)
          metadata[:booking_id] = reference.id
          metadata[:event_id] = reference.event.id
          metadata[:event_title] = reference.event.title
        end
        
        transaction = PaymentTransaction.create!(
          wallet: wallet,
          user: current_user,
          transaction_type: 'payment',
          status: 'pending',
          amount: amount,
          currency: currency,
          payment_method: 'credit_card', # Default, can be updated later
          payment_provider: provider,
          reference: reference,
          metadata: metadata.to_json
        )

        # Create Payment Intent via Stripe
        provider_config = PaymentProvider.active_lookup(provider)
        unless provider_config
          api_error(message: "Payment provider '#{provider}' not found or inactive", status: :bad_request)
          return
        end

        stripe_provider = StripePaymentProvider.new(provider_config)

        # Prepare Stripe metadata
        stripe_metadata = {
          user_id: current_user.id,
          reference_type: reference_type,
          reference_id: reference_id
        }
        
        # Add booking-specific metadata
        if reference_type == 'Booking' && reference.is_a?(Booking)
          stripe_metadata.merge!({
            booking_id: reference.id,
            event_id: reference.event.id,
            event_title: reference.event.title,
            payment_type: metadata[:payment_type],
            booking_price: metadata[:booking_price],
            remaining_amount: metadata[:remaining_amount]
          })
        end
        
        result = stripe_provider.create_payment_intent(
          amount: amount,
          currency: currency,
          transaction_id: transaction.id,
          metadata: stripe_metadata,
          customer_id: customer_id,
          payment_method_id: payment_method_id
        )

        # Update transaction with payment intent ID
        transaction.update!(
          provider_transaction_id: result[:payment_intent_id],
          provider_response: result.to_json
        )

        response_data = {
          payment_intent_id: result[:payment_intent_id],
          client_secret: result[:client_secret],
          transaction_id: transaction.id,
          status: result[:status],
          amount: result[:amount],
          currency: result[:currency]
        }
        
        # Include booking info if reference is a booking
        if reference_type == 'Booking' && reference.is_a?(Booking)
          booking = reference
          response_data[:booking_id] = booking.id
          response_data[:payment_type] = metadata[:payment_type]
          response_data[:booking_price] = booking.price.to_f
          response_data[:booking_currency] = booking.currency
          response_data[:remaining_amount] = booking.remaining_amount.to_f
          response_data[:current_paid_amount] = booking.paid_amount.to_f
          response_data[:original_price] = booking.original_price&.to_f
          response_data[:discount_amount] = booking.discount_amount&.to_f
          response_data[:promo_code] = booking.promo_code
        end
        
        api_success(
          data: response_data,
          message: 'Payment intent created successfully',
          status: :created
        )
      rescue PaymentService::InvalidProviderError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        transaction&.update!(status: 'failed', description: e.message)
        api_error(message: "Failed to create payment intent: #{e.message}", status: :unprocessable_entity)
      end

      # POST /api/v1/payments/confirm_intent (for Flutter)
      def confirm_intent
        payment_intent_id = params[:payment_intent_id]
        payment_method_id = params[:payment_method_id]
        return_url = params[:return_url]

        unless payment_intent_id
          api_error(message: 'Payment intent ID is required', status: :bad_request)
          return
        end

        # Find transaction
        transaction = PaymentTransaction.find_by(provider_transaction_id: payment_intent_id)
        unless transaction
          api_error(message: 'Transaction not found', status: :not_found)
          return
        end

        unless transaction.user_id == current_user.id
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        # Confirm Payment Intent via Stripe
        provider_config = PaymentProvider.active_lookup(transaction.payment_provider)
        unless provider_config
          api_error(message: "Payment provider '#{transaction.payment_provider}' not found or inactive", status: :bad_request)
          return
        end

        stripe_provider = StripePaymentProvider.new(provider_config)

        result = stripe_provider.confirm_payment_intent(
          payment_intent_id: payment_intent_id,
          payment_method_id: payment_method_id,
          return_url: return_url
        )

        # Update transaction status based on result
        if result[:status] == 'succeeded'
          transaction.update!(
            status: 'completed',
            provider_response: result.to_json,
            processed_at: Time.current
          )
        elsif result[:status] == 'requires_action'
          transaction.update!(
            status: 'processing',
            provider_response: result.to_json
          )
        else
          transaction.update!(
            status: 'failed',
            description: "Payment intent status: #{result[:status]}",
            provider_response: result.to_json
          )
        end

        api_success(
          data: {
            payment_intent_id: result[:payment_intent_id],
            status: result[:status],
            transaction: transaction_response(transaction)
          },
          message: 'Payment intent confirmed',
          status: :ok
        )
      rescue PaymentService::InvalidProviderError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        transaction&.update!(status: 'failed', description: e.message)
        api_error(message: "Failed to confirm payment intent: #{e.message}", status: :unprocessable_entity)
      end

      # GET /api/v1/payments/intent/:payment_intent_id (check status)
      def intent_status
        payment_intent_id = params[:payment_intent_id]

        unless payment_intent_id
          api_error(message: 'Payment intent ID is required', status: :bad_request)
          return
        end

        # Find transaction
        transaction = PaymentTransaction.find_by(provider_transaction_id: payment_intent_id)
        unless transaction
          api_error(message: 'Transaction not found', status: :not_found)
          return
        end

        unless transaction.user_id == current_user.id
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        # Retrieve Payment Intent status from Stripe
        provider_config = PaymentProvider.active_lookup(transaction.payment_provider)
        unless provider_config
          api_error(message: "Payment provider '#{transaction.payment_provider}' not found or inactive", status: :bad_request)
          return
        end

        stripe_provider = StripePaymentProvider.new(provider_config)

        result = stripe_provider.retrieve_payment_intent(payment_intent_id: payment_intent_id)

        # Update transaction status if changed
        if result[:status] == 'succeeded' && transaction.status != 'completed'
          transaction.update!(
            status: 'completed',
            provider_response: result.to_json,
            processed_at: Time.current
          )
        elsif result[:status] == 'requires_payment_method' && transaction.status != 'failed'
          transaction.update!(
            status: 'failed',
            description: 'Payment method required',
            provider_response: result.to_json
          )
        end

        api_success(
          data: {
            payment_intent_id: result[:payment_intent_id],
            status: result[:status],
            transaction: transaction_response(transaction)
          },
          status: :ok
        )
      rescue PaymentService::InvalidProviderError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        api_error(message: "Failed to retrieve payment intent: #{e.message}", status: :unprocessable_entity)
      end

      private

      def transaction_response(transaction)
        {
          id: transaction.id,
          transaction_type: transaction.transaction_type,
          status: transaction.status,
          amount: transaction.amount.to_f,
          currency: transaction.currency,
          payment_method: transaction.payment_method,
          payment_provider: transaction.payment_provider,
          fee: transaction.fee.to_f,
          net_amount: transaction.net_amount.to_f,
          created_at: transaction.created_at.iso8601
        }
      end
    end
  end
end

