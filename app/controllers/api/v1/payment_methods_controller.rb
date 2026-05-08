module Api
  module V1
    class PaymentMethodsController < ApplicationController
      before_action :require_authentication!
      before_action :set_payment_method, only: [:show, :update, :destroy, :set_default]

      # GET /api/v1/payment_methods
      def index
        payment_methods = current_user.payment_methods.active
        
        # Filter by provider
        payment_methods = payment_methods.by_provider(params[:provider]) if params[:provider].present?
        
        # Filter by type
        payment_methods = payment_methods.by_type(params[:type]) if params[:type].present?
        
        api_success(
          data: {
            payment_methods: payment_methods.map { |pm| payment_method_response(pm) }
          },
          status: :ok
        )
      end

      # GET /api/v1/payment_methods/:id
      def show
        api_success(
          data: {
            payment_method: payment_method_response(@payment_method, include_details: true)
          },
          status: :ok
        )
      end

      # POST /api/v1/payment_methods
      def create
        payment_method = current_user.payment_methods.build(payment_method_params)
        
        if payment_method.save
          api_success(
            data: { payment_method: payment_method_response(payment_method, include_details: true) },
            message: 'Payment method added successfully',
            status: :created
          )
        else
          api_validation_error(errors: payment_method.errors.full_messages)
        end
      end

      # PATCH /api/v1/payment_methods/:id
      def update
        if @payment_method.update(payment_method_params)
          api_success(
            data: { payment_method: payment_method_response(@payment_method, include_details: true) },
            message: 'Payment method updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @payment_method.errors.full_messages)
        end
      end

      # DELETE /api/v1/payment_methods/:id
      def destroy
        if @payment_method.update(status: 'inactive')
          api_success(message: 'Payment method removed successfully', status: :ok)
        else
          api_validation_error(errors: @payment_method.errors.full_messages)
        end
      end

      # POST /api/v1/payment_methods/:id/set_default
      def set_default
        @payment_method.update!(is_default: true)
        
        api_success(
          data: { payment_method: payment_method_response(@payment_method) },
          message: 'Payment method set as default',
          status: :ok
        )
      end

      private

      def set_payment_method
        @payment_method = current_user.payment_methods.find_by(id: params[:id])
        unless @payment_method
          api_error(message: 'Payment method not found', status: :not_found)
        end
      end

      def payment_method_params
        params.require(:payment_method).permit(
          :payment_method_type,
          :provider,
          :provider_payment_method_id,
          :card_brand,
          :card_last4,
          :card_exp_month,
          :card_exp_year,
          :billing_name,
          :billing_email,
          :billing_phone,
          billing_address: {},
          metadata: {}
        )
      end

      def payment_method_response(payment_method, include_details: false)
        response = {
          id: payment_method.id,
          payment_method_type: payment_method.payment_method_type,
          provider: payment_method.provider,
          display_name: payment_method.display_name,
          is_default: payment_method.is_default,
          status: payment_method.status,
          created_at: payment_method.created_at.iso8601,
          updated_at: payment_method.updated_at.iso8601
        }

        if include_details
          response[:card_brand] = payment_method.card_brand
          response[:card_last4] = payment_method.card_last4
          response[:card_exp_month] = payment_method.card_exp_month
          response[:card_exp_year] = payment_method.card_exp_year
          response[:billing_name] = payment_method.billing_name
          response[:billing_email] = payment_method.billing_email
          response[:billing_phone] = payment_method.billing_phone
          response[:billing_address] = payment_method.billing_address_hash
          response[:metadata] = payment_method.metadata_hash
        end

        response
      end
    end
  end
end


