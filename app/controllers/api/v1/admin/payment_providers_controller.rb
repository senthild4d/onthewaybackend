module Api
  module V1
    module Admin
      class PaymentProvidersController < ApplicationController
        before_action :require_authentication!
        before_action :require_admin!
        before_action :set_payment_provider, only: [:show, :update, :destroy, :activate, :deactivate]

        # GET /api/v1/admin/payment_providers
        def index
          payment_providers = PaymentProvider.all.order(:name)
          
          api_success(
            data: {
              payment_providers: payment_providers.map { |pp| payment_provider_response(pp) }
            },
            status: :ok
          )
        end

        # GET /api/v1/admin/payment_providers/:id
        def show
          api_success(
            data: {
              payment_provider: payment_provider_response(@payment_provider, include_credentials: true)
            },
            status: :ok
          )
        end

        # POST /api/v1/admin/payment_providers
        def create
          payment_provider = PaymentProvider.new(payment_provider_params)
          
          if payment_provider.save
            api_success(
              data: { payment_provider: payment_provider_response(payment_provider, include_credentials: true) },
              message: 'Payment provider created successfully',
              status: :created
            )
          else
            api_validation_error(errors: payment_provider.errors.full_messages)
          end
        end

        # PATCH /api/v1/admin/payment_providers/:id
        def update
          if @payment_provider.update(payment_provider_params)
            api_success(
              data: { payment_provider: payment_provider_response(@payment_provider, include_credentials: true) },
              message: 'Payment provider updated successfully',
              status: :ok
            )
          else
            api_validation_error(errors: @payment_provider.errors.full_messages)
          end
        end

        # DELETE /api/v1/admin/payment_providers/:id
        def destroy
          if @payment_provider.destroy
            api_success(message: 'Payment provider deleted successfully', status: :ok)
          else
            api_validation_error(errors: @payment_provider.errors.full_messages)
          end
        end

        # POST /api/v1/admin/payment_providers/:id/activate
        def activate
          if @payment_provider.update(status: 'active')
            api_success(
              data: { payment_provider: payment_provider_response(@payment_provider) },
              message: 'Payment provider activated successfully',
              status: :ok
            )
          else
            api_validation_error(errors: @payment_provider.errors.full_messages)
          end
        end

        # POST /api/v1/admin/payment_providers/:id/deactivate
        def deactivate
          if @payment_provider.update(status: 'inactive')
            api_success(
              data: { payment_provider: payment_provider_response(@payment_provider) },
              message: 'Payment provider deactivated successfully',
              status: :ok
            )
          else
            api_validation_error(errors: @payment_provider.errors.full_messages)
          end
        end

        private

        def require_admin!
          unless current_user&.role_admin?
            api_error(message: 'Admin access required', status: :forbidden)
          end
        end

        def set_payment_provider
          @payment_provider = PaymentProvider.find_by(id: params[:id])
          unless @payment_provider
            api_error(message: 'Payment provider not found', status: :not_found)
          end
        end

        def payment_provider_params
          params.require(:payment_provider).permit(
            :name,
            :provider_type,
            :status,
            :description,
            :is_default,
            credentials: {},
            settings: {}
          )
        end

        def payment_provider_response(payment_provider, include_credentials: false)
          response = {
            id: payment_provider.id,
            name: payment_provider.name,
            provider_type: payment_provider.provider_type,
            status: payment_provider.status,
            is_default: payment_provider.is_default,
            description: payment_provider.description,
            settings: payment_provider.settings_hash,
            created_at: payment_provider.created_at.iso8601,
            updated_at: payment_provider.updated_at.iso8601
          }

          if include_credentials
            # Only show masked credentials for security
            creds = payment_provider.credentials_hash
            response[:credentials] = {
              api_key: mask_string(creds['api_key'] || creds[:api_key]),
              secret_key: mask_string(creds['secret_key'] || creds[:secret_key]),
              client_id: mask_string(creds['client_id'] || creds[:client_id]),
              client_secret: mask_string(creds['client_secret'] || creds[:client_secret]),
              webhook_secret: mask_string(creds['webhook_secret'] || creds[:webhook_secret]),
              mode: creds['mode'] || creds[:mode]
            }
          end

          response
        end

        def mask_string(str)
          return nil if str.blank?
          return str if str.length <= 4

          "#{str[0..3]}...#{str[-4..-1]}"
        end
      end
    end
  end
end
