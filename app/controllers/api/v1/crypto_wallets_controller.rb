module Api
  module V1
    class CryptoWalletsController < ApplicationController
      before_action :require_authentication!
      before_action :set_crypto_wallet, only: [:show, :update, :destroy]

      # GET /api/v1/crypto_wallets
      def index
        crypto_wallets = current_user.crypto_wallets.active
        
        api_success(
          data: {
            crypto_wallets: crypto_wallets.map { |cw| crypto_wallet_response(cw) }
          },
          status: :ok
        )
      end

      # GET /api/v1/crypto_wallets/:id
      def show
        api_success(
          data: {
            crypto_wallet: crypto_wallet_response(@crypto_wallet, include_details: true)
          },
          status: :ok
        )
      end

      # POST /api/v1/crypto_wallets
      def create
        crypto_wallet = current_user.crypto_wallets.build(crypto_wallet_params)
        
        if crypto_wallet.save
          api_success(
            data: { crypto_wallet: crypto_wallet_response(crypto_wallet, include_details: true) },
            message: 'Crypto wallet added successfully',
            status: :created
          )
        else
          api_validation_error(errors: crypto_wallet.errors.full_messages)
        end
      end

      # PATCH /api/v1/crypto_wallets/:id
      def update
        if @crypto_wallet.update(crypto_wallet_params)
          api_success(
            data: { crypto_wallet: crypto_wallet_response(@crypto_wallet, include_details: true) },
            message: 'Crypto wallet updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @crypto_wallet.errors.full_messages)
        end
      end

      # DELETE /api/v1/crypto_wallets/:id
      def destroy
        if @crypto_wallet.update(status: 'archived')
          api_success(message: 'Crypto wallet archived successfully', status: :ok)
        else
          api_validation_error(errors: @crypto_wallet.errors.full_messages)
        end
      end

      private

      def set_crypto_wallet
        @crypto_wallet = current_user.crypto_wallets.find_by(id: params[:id])
        unless @crypto_wallet
          api_error(message: 'Crypto wallet not found', status: :not_found)
        end
      end

      def crypto_wallet_params
        params.require(:crypto_wallet).permit(:crypto_currency, :wallet_address, :wallet_type, :network, :metadata)
      end

      def crypto_wallet_response(crypto_wallet, include_details: false)
        response = {
          id: crypto_wallet.id,
          crypto_currency: crypto_wallet.crypto_currency,
          wallet_address: crypto_wallet.wallet_address,
          short_address: crypto_wallet.short_address,
          wallet_type: crypto_wallet.wallet_type,
          network: crypto_wallet.network,
          status: crypto_wallet.status,
          display_name: crypto_wallet.display_name,
          created_at: crypto_wallet.created_at.iso8601,
          updated_at: crypto_wallet.updated_at.iso8601
        }

        if include_details
          response[:metadata] = crypto_wallet.metadata_hash
        end

        response
      end
    end
  end
end

