# frozen_string_literal: true

module Api
  module V1
    class SupportTicketsController < ApplicationController
      before_action :require_authentication!
      before_action :set_ticket, only: [:show, :update]
      before_action :require_support_or_admin!, only: [:index, :show, :update, :reasons]

      # POST /api/v1/support/tickets
      def create
        ticket = SupportTicket.new(ticket_params)
        ticket.user = current_user
        ticket.status = 'open'

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

