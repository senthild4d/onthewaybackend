# frozen_string_literal: true

module Api
  module V1
    class SupportTicketsController < ApplicationController
      before_action :require_authentication!
      before_action :set_ticket, only: [:show, :update]
      before_action :require_support_or_admin!, only: [:index, :show, :update]

      # POST /api/v1/support/tickets
      def create
        ticket = SupportTicket.new(ticket_params)
        ticket.user = current_user
        ticket.status = 'open'
        normalize_related_fields(ticket)

        unless related_record_allowed?(ticket)
          api_error(message: 'Related property or viewing is not available for this user', status: :unprocessable_entity)
          return
        end

        if ticket.save
          api_success(
            data: { ticket: ticket_response(ticket) },
            message: 'Support ticket created',
            status: :created
          )
        else
          api_validation_error(errors: ticket.errors.full_messages)
        end
      end

      # GET /api/v1/support/tickets/my
      def my
        tickets = SupportTicket.where(user_id: current_user.id)
                               .order(created_at: :desc)
        tickets = tickets.where(status: params[:status]) if params[:status].present?

        api_success(
          data: {
            tickets: tickets.map { |t| ticket_response(t) }
          },
          status: :ok
        )
      end

      # GET /api/v1/support/tickets
      def index
        tickets = SupportTicket.all
        tickets = tickets.where(status: params[:status]) if params[:status].present?
        tickets = tickets.where(reason: params[:reason]) if params[:reason].present?
        tickets = tickets.where(assigned_to_id: params[:assigned_to_id]) if params[:assigned_to_id].present?

        tickets = tickets.order(created_at: :desc).limit([params[:limit]&.to_i || 50, 200].min)

        api_success(
          data: {
            tickets: tickets.map { |t| ticket_response(t) }
          },
          status: :ok
        )
      end

      # GET /api/v1/support/tickets/:id
      def show
        api_success(
          data: { ticket: ticket_response(@ticket, include_user: true) },
          status: :ok
        )
      end

      # PATCH /api/v1/support/tickets/:id
      def update
        if @ticket.update(ticket_update_params)
          api_success(
            data: { ticket: ticket_response(@ticket, include_user: true) },
            message: 'Ticket updated',
            status: :ok
          )
        else
          api_validation_error(errors: @ticket.errors.full_messages)
        end
      end

      # DELETE /api/v1/support/tickets/:id
      def destroy
        ticket = SupportTicket.find_by(id: params[:id], user_id: current_user.id)
        unless ticket
          api_error(message: 'Ticket not found', status: :not_found)
          return
        end

        ticket.destroy!
        api_success(
          data: { id: params[:id] },
          message: 'Support ticket deleted',
          status: :ok
        )
      end

      # GET /api/v1/support/reasons
      def reasons
        api_success(
          data: {
            reasons: SupportTicket::REASONS.map do |key|
              {
                key: key,
                label: key.humanize
              }
            end
          },
          status: :ok
        )
      end

      # GET /api/v1/support/ticket_options
      def ticket_options
        api_success(
          data: {
            reasons: reason_options,
            related_types: [
              { key: 'property', label: 'Property' },
              { key: 'property_viewing', label: 'Property Viewing' }
            ],
            properties: support_property_options,
            property_viewings: support_property_viewing_options
          },
          status: :ok
        )
      end

      private

      def set_ticket
        @ticket = SupportTicket.find_by(id: params[:id])
        unless @ticket
          api_error(message: 'Ticket not found', status: :not_found)
        end
      end

      def require_support_or_admin!
        unless current_user&.admin?
          api_error(message: 'Only admin can perform this action', status: :forbidden)
        end
      end

      def ticket_params
        params.require(:ticket).permit(
          :reason,
          :custom_reason,
          :description,
          :related_type,
          :related_id
        )
      end

      def normalize_related_fields(ticket)
        ticket.related_type = ticket.related_type.to_s.underscore.presence
      end

      def related_record_allowed?(ticket)
        return true if ticket.related_type.blank? && ticket.related_id.blank?
        return false if ticket.related_type.blank? || ticket.related_id.blank?

        case ticket.related_type
        when 'property'
          user_related_properties.exists?(id: ticket.related_id)
        when 'property_viewing'
          current_user.property_viewings.exists?(id: ticket.related_id)
        else
          false
        end
      end

      def reason_options
        SupportTicket::REASONS.map do |key|
          {
            key: key,
            label: key.humanize
          }
        end
      end

      def support_property_options
        user_related_properties
          .order(created_at: :desc)
          .limit(100)
          .map do |property|
            {
              id: property.id,
              label: property_dropdown_label(property),
              title: property.title,
              purpose: property.purpose,
              listing_status: property.listing_status,
              approval_status: property.approval_status
            }
          end
      end

      def support_property_viewing_options
        current_user.property_viewings
                    .includes(:property)
                    .recent
                    .limit(100)
                    .map do |viewing|
          property = viewing.property
          {
            id: viewing.id,
            label: property_viewing_dropdown_label(viewing),
            property_id: property&.id,
            property_title: property&.title,
            status: viewing.status,
            requested_for: viewing.requested_for&.iso8601
          }
        end
      end

      def user_related_properties
        viewed_property_ids = current_user.property_viewings.select(:property_id)
        Property.where(owner_id: current_user.id).or(Property.where(id: viewed_property_ids)).distinct
      end

      def property_dropdown_label(property)
        [property.title, property.city].compact.join(' - ')
      end

      def property_viewing_dropdown_label(viewing)
        property_title = viewing.property&.title || 'Property'
        date = viewing.requested_for&.strftime('%d %b %Y')
        ["Viewing #{viewing.id}", property_title, date].compact.join(' - ')
      end

      def ticket_update_params
        params.require(:ticket).permit(
          :status,
          :priority,
          :assigned_to_id,
          :custom_reason,
          :description
        )
      end

      def ticket_response(ticket, include_user: false)
        data = {
          id: ticket.id,
          reason: ticket.reason,
          custom_reason: ticket.custom_reason,
          description: ticket.description,
          status: ticket.status,
          priority: ticket.priority,
          related_type: ticket.related_type,
          related_id: ticket.related_id,
          created_at: ticket.created_at,
          updated_at: ticket.updated_at
        }

        if include_user
          data[:user] = ticket.user ? {
            id: ticket.user.id,
            name: ticket.user.name,
            username: ticket.user.username,
            email: ticket.user.email
          } : nil
          data[:assigned_to] = ticket.assigned_to ? {
            id: ticket.assigned_to.id,
            name: ticket.assigned_to.name,
            username: ticket.assigned_to.username
          } : nil
        end

        data
      end
    end
  end
end

