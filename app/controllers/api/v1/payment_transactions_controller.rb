module Api
  module V1
    class PaymentTransactionsController < ApplicationController
      before_action :require_authentication!
      before_action :set_transaction, only: [:show, :refund]

      # GET /api/v1/payment_transactions
      def index
        transactions = current_user.payment_transactions.includes(:wallet)
        
        # Filter by type
        transactions = transactions.by_type(params[:transaction_type]) if params[:transaction_type].present?
        
        # Filter by status
        transactions = transactions.by_status(params[:status]) if params[:status].present?
        
        # Filter by payment method
        transactions = transactions.by_payment_method(params[:payment_method]) if params[:payment_method].present?
        
        # Filter by currency
        transactions = transactions.where(currency: params[:currency].upcase) if params[:currency].present?
        
        # Limit results
        limit = [params[:limit]&.to_i || 50, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = transactions.count
        transactions = transactions.recent.limit(limit).offset(offset)
        
        api_success(
          data: {
            transactions: transactions.map { |tx| transaction_response(tx) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/payment_transactions/:id
      def show
        api_success(
          data: {
            transaction: transaction_response(@transaction, include_details: true)
          },
          status: :ok
        )
      end

      # POST /api/v1/payment_transactions/:id/refund
      def refund
        unless @transaction.status_completed?
          api_error(message: 'Only completed transactions can be refunded', status: :bad_request)
          return
        end

        amount = params[:amount]&.to_d || @transaction.amount
        reason = params[:reason]

        payment_service = PaymentService.new(current_user, @transaction.payment_provider)
        result = payment_service.process_refund(
          original_transaction: @transaction,
          amount: amount,
          reason: reason
        )

        if result[:success]
          api_success(
            data: {
              refund_transaction: transaction_response(result[:transaction], include_details: true)
            },
            message: 'Refund processed successfully',
            status: :created
          )
        else
          api_error(message: result[:error] || 'Refund failed', status: :unprocessable_entity)
        end
      end

      private

      def set_transaction
        @transaction = current_user.payment_transactions.find_by(id: params[:id])
        unless @transaction
          api_error(message: 'Transaction not found', status: :not_found)
        end
      end

      def transaction_response(transaction, include_details: false)
        response = {
          id: transaction.id,
          transaction_type: transaction.transaction_type,
          status: transaction.status,
          amount: transaction.amount.to_f,
          currency: transaction.currency,
          payment_method: transaction.payment_method,
          payment_provider: transaction.payment_provider,
          fee: transaction.fee.to_f,
          net_amount: transaction.net_amount.to_f,
          description: transaction.description,
          created_at: transaction.created_at.iso8601,
          updated_at: transaction.updated_at.iso8601
        }

        if include_details
          response[:wallet] = {
            id: transaction.wallet.id,
            currency: transaction.wallet.currency
          }
          response[:provider_transaction_id] = transaction.provider_transaction_id
          response[:reference] = transaction.reference_type ? {
            type: transaction.reference_type,
            id: transaction.reference_id
          } : nil
          response[:metadata] = transaction.metadata_hash
          response[:processed_at] = transaction.processed_at&.iso8601
        end

        response
      end
    end
  end
end

