module Api
  module V1
    class PromoCodesController < ApplicationController
      before_action :require_authentication!
      before_action :require_admin!, except: [:validate]

      # GET /api/v1/promo_codes
      def index
        promo_codes = PromoCode.order(created_at: :desc)
        api_success(data: { promo_codes: promo_codes.map { |promo| promo_response(promo) } }, status: :ok)
      end

      # POST /api/v1/promo_codes
      def create
        promo = PromoCode.new(promo_params)
        if promo.save
          api_success(data: { promo_code: promo_response(promo) }, message: 'Promo code created', status: :created)
        else
          api_validation_error(errors: promo.errors.full_messages)
        end
      end

      # PATCH /api/v1/promo_codes/:id
      def update
        promo = PromoCode.find_by(id: params[:id])
        unless promo
          api_error(message: 'Promo code not found', status: :not_found)
          return
        end

        if promo.update(promo_params)
          api_success(data: { promo_code: promo_response(promo) }, message: 'Promo code updated', status: :ok)
        else
          api_validation_error(errors: promo.errors.full_messages)
        end
      end

      # DELETE /api/v1/promo_codes/:id
      def destroy
        promo = PromoCode.find_by(id: params[:id])
        unless promo
          api_error(message: 'Promo code not found', status: :not_found)
          return
        end

        promo.destroy
        api_success(message: 'Promo code deleted', status: :ok)
      end

      # GET /api/v1/promo_codes/validate?code=ABC&event_id=... or &venue_id=...
      def validate
        code = params[:code].to_s.strip.upcase
        promo = PromoCode.find_by(code: code)
        unless promo
          api_error(message: 'Invalid promo code', status: :not_found)
          return
        end

        event = params[:event_id].present? ? Event.find_by(id: params[:event_id]) : nil
        venue = params[:venue_id].present? ? Venue.find_by(id: params[:venue_id]) : nil
        unless promo.usable?(event: event, venue: venue)
          api_error(message: 'Promo code is not available', status: :unprocessable_entity)
          return
        end

        api_success(
          data: {
            promo_code: promo_response(promo)
          },
          status: :ok
        )
      end

      private

      def require_admin!
        require_role!('admin')
      end

      def promo_params
        params.require(:promo_code).permit(
          :event_id,
          :venue_id,
          :code,
          :label,
          :description,
          :discount_type,
          :discount_value,
          :currency,
          :starts_at,
          :ends_at,
          :max_uses,
          :is_active
        )
      end

      def promo_response(promo)
        {
          id: promo.id,
          event_id: promo.event_id,
          venue_id: promo.venue_id,
          code: promo.code,
          label: promo.label,
          description: promo.description,
          discount_type: promo.discount_type,
          discount_value: promo.discount_value.to_f,
          currency: promo.currency,
          starts_at: promo.starts_at&.iso8601,
          ends_at: promo.ends_at&.iso8601,
          max_uses: promo.max_uses,
          uses_count: promo.uses_count,
          is_active: promo.is_active
        }
      end
    end
  end
end
