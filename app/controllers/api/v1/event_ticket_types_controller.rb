# frozen_string_literal: true

module Api
  module V1
    class EventTicketTypesController < ApplicationController
      before_action :require_authentication!
      before_action :set_event
      before_action :authorize_manage_event!
      before_action :set_ticket_type, only: [:update, :destroy]

      # GET /api/v1/events/:event_id/ticket_types
      def index
        types = @event.event_ticket_types.order(:display_order, :created_at)
        api_success(data: { ticket_types: types.map { |t| ticket_type_response(t) } }, status: :ok)
      end

      # PUT /api/v1/events/:event_id/ticket_types
      # Replaces all ticket types (max #{Event::MAX_TICKET_TYPES}). Blocked if any tickets already sold.
      def replace
        list = params[:ticket_types] || params.dig(:data, :ticket_types)
        list ||= params.permit(ticket_types: [:name, :price, :quantity_total, :display_order])[:ticket_types]
        unless list.is_a?(Array)
          api_error(message: 'ticket_types must be an array', status: :bad_request)
          return
        end

        if list.size > Event::MAX_TICKET_TYPES
          api_error(message: "Maximum #{Event::MAX_TICKET_TYPES} ticket types per event", status: :bad_request)
          return
        end

        @event.replace_ticket_types!(list)

        api_success(
          data: { ticket_types: @event.event_ticket_types.order(:display_order).map { |t| ticket_type_response(t) } },
          message: 'Ticket types saved',
          status: :ok
        )
      rescue ActiveRecord::RecordInvalid
        api_validation_error(errors: @event.errors.full_messages)
      rescue ArgumentError => e
        api_error(message: e.message, status: :bad_request)
      end

      # POST /api/v1/events/:event_id/ticket_types
      # Body: { "ticket_type": { "name", "price", "quantity_total", "display_order" } }
      def create
        if @event.event_ticket_types.count >= Event::MAX_TICKET_TYPES
          api_error(message: "Maximum #{Event::MAX_TICKET_TYPES} ticket types per event", status: :bad_request)
          return
        end

        attrs = ticket_type_attributes_for_write
        display_order = attrs.delete(:display_order)
        display_order = (@event.event_ticket_types.maximum(:display_order) || -1) + 1 if display_order.nil?

        ticket_type = @event.event_ticket_types.build(
          attrs.merge(
            display_order: display_order,
            currency: @event.currency.presence || 'EUR',
            quantity_sold: 0
          )
        )

        if ticket_type.save
          api_success(
            data: { ticket_type: ticket_type_response(ticket_type) },
            message: 'Ticket type created',
            status: :created
          )
        else
          api_validation_error(errors: ticket_type.errors.full_messages)
        end
      end

      # PATCH /api/v1/events/:event_id/ticket_types/:id
      def update
        src = params[:ticket_type].presence || params.dig(:data, :ticket_type)
        if src.blank?
          api_error(message: 'ticket_type parameters required', status: :bad_request)
          return
        end

        attrs = ticket_type_attributes_for_write
        if attrs.empty?
          api_error(message: 'No permitted ticket_type fields provided', status: :bad_request)
          return
        end

        if @ticket_type.update(attrs)
          api_success(
            data: { ticket_type: ticket_type_response(@ticket_type.reload) },
            message: 'Ticket type updated',
            status: :ok
          )
        else
          api_validation_error(errors: @ticket_type.errors.full_messages)
        end
      end

      # DELETE /api/v1/events/:event_id/ticket_types/:id
      def destroy
        if @ticket_type.quantity_sold.positive?
          api_error(
            message: 'Cannot delete a ticket type that has sold or reserved inventory',
            status: :unprocessable_entity
          )
          return
        end

        if @ticket_type.destroy
          api_success(data: {}, message: 'Ticket type deleted', status: :ok)
        else
          msg = @ticket_type.errors.full_messages.presence&.join(', ') || 'Cannot delete this ticket type'
          api_error(message: msg, status: :unprocessable_entity)
        end
      end

      private

      def set_event
        @event = Event.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end

      def set_ticket_type
        @ticket_type = @event.event_ticket_types.find_by(id: params[:id])
        return if @ticket_type

        api_error(message: 'Ticket type not found', status: :not_found)
      end

      def ticket_type_params
        src = params[:ticket_type].presence || params.dig(:data, :ticket_type)
        return ActionController::Parameters.new.permit unless src.present?

        src = ActionController::Parameters.new(src) unless src.is_a?(ActionController::Parameters)
        src.permit(:name, :price, :quantity_total, :display_order)
      end

      def ticket_type_attributes_for_write
        p = ticket_type_params
        h = p.to_unsafe_h.symbolize_keys
        h[:price] = h[:price].to_d if h.key?(:price)
        h[:quantity_total] = h[:quantity_total].to_i if h.key?(:quantity_total)
        h[:display_order] = h[:display_order].to_i if h.key?(:display_order)
        h
      end

      def authorize_manage_event!
        return if current_user.role_admin?
        if @event.creator_id == current_user.id
          return
        end
        if @event.venue&.owner_id == current_user.id
          return
        end
        api_error(message: 'You cannot manage ticket types for this event', status: :forbidden)
      end

      def ticket_type_response(t)
        {
          # UUID string — use as `event_ticket_type_id` in booking `ticket_lines`, and as `:id` in PATCH/DELETE .../ticket_types/:id
          id: t.id.to_s,
          name: t.name,
          price: t.price.to_f,
          currency: t.currency || @event.currency,
          quantity_total: t.quantity_total,
          quantity_sold: t.quantity_sold,
          quantity_available: t.quantity_available,
          display_order: t.display_order
        }
      end
    end
  end
end
