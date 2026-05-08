module Api
  module V1
    class WalletsController < ApplicationController
      before_action :require_authentication!
      before_action :set_wallet, only: [:show, :update]

      # GET /api/v1/wallets
      def index
        wallets = current_user.wallets.active.includes(:payment_transactions)
        
        api_success(
          data: {
            wallets: wallets.map { |wallet| wallet_response(wallet) }
          },
          status: :ok
        )
      end

      # GET /api/v1/wallets/:id
      def show
        api_success(
          data: {
            wallet: wallet_response(@wallet, include_transactions: true)
          },
          status: :ok
        )
      end

      # GET /api/v1/wallets/by_currency/:currency
      def by_currency
        currency = params[:currency]&.upcase
        wallet = current_user.wallets.find_by(currency: currency)
        
        if wallet
          api_success(
            data: {
              wallet: wallet_response(wallet, include_transactions: true)
            },
            status: :ok
          )
        else
          # Create wallet if it doesn't exist
          wallet = current_user.wallets.create!(
            currency: currency,
            balance: 0,
            locked_balance: 0,
            status: 'active'
          )
          
          api_success(
            data: {
              wallet: wallet_response(wallet)
            },
            status: :created
          )
        end
      end

      private

      def set_wallet
        @wallet = current_user.wallets.find_by(id: params[:id])
        unless @wallet
          api_error(message: 'Wallet not found', status: :not_found)
        end
      end

      def wallet_response(wallet, include_transactions: false)
        response = {
          id: wallet.id,
          currency: wallet.currency,
          balance: wallet.balance.to_f,
          locked_balance: wallet.locked_balance.to_f,
          available_balance: wallet.available_balance.to_f,
          status: wallet.status,
          created_at: wallet.created_at.iso8601,
          updated_at: wallet.updated_at.iso8601
        }

        if include_transactions
          recent_transactions = wallet.payment_transactions.recent.limit(10)
          response[:recent_transactions] = recent_transactions.map { |tx| transaction_response(tx) }
        end

        response
      end

      def transaction_response(transaction)
        {
          id: transaction.id,
          transaction_type: transaction.transaction_type,
          status: transaction.status,
          amount: transaction.amount.to_f,
          currency: transaction.currency,
          payment_method: transaction.payment_method,
          fee: transaction.fee.to_f,
          net_amount: transaction.net_amount.to_f,
          description: transaction.description,
          created_at: transaction.created_at.iso8601
        }
      end
    end
  end
end

