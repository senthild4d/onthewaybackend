# frozen_string_literal: true

module Api
  module V1
    class TicketEntitlementsController < ApplicationController
      before_action :require_authentication!
      before_action :set_entitlement, except: [:index, :claim, :my_tickets]

      # GET /api/v1/users/me/tickets
      # All ticket entitlements where current user is purchaser or holder (flat list for "My tickets").
      def my_tickets
        scope = TicketEntitlement
                .for_holder(current_user)
                .joins(booking: :event)
                .includes(:event_ticket_type, booking: { event: [:venue, { photos_attachments: :blob }] })

        scope = scope.where('ticket_entitlements.status = ?', params[:status]) if params[:status].present?
        scope = scope.where(bookings: { event_id: params[:event_id] }) if params[:event_id].present?

        case params[:time_filter]
        when 'upcoming'
          scope = scope.where('events.starts_at > ?', Time.current)
        when 'past'
          scope = scope.where('events.ends_at < ?', Time.current)
        end

        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = scope.count
        ents = scope.order('events.starts_at ASC, ticket_entitlements.position ASC').limit(limit).offset(offset)

        api_success(
          data: {
            tickets: ents.map { |e| entitlement_response(e, e.booking, include_event: true, request: request) },
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

      # GET /api/v1/bookings/:booking_id/tickets
      def index
        booking = Booking.find_by(id: params[:booking_id])
        unless booking
          api_error(message: 'Booking not found', status: :not_found)
          return
        end
        unless can_view_booking?(booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        ents = booking.ticket_entitlements.includes(:holder, :event_ticket_type).order(:position)
        api_success(
          data: {
            tickets: ents.map { |e| entitlement_response(e, booking) }
          },
          status: :ok
        )
      end

      # GET /api/v1/ticket_entitlements/:id/qr
      def qr
        unless can_view_entitlement?(@entitlement)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        require 'rqrcode'

        payload = {
          type: 'Ticket',
          ticket_entitlement_id: @entitlement.id,
          booking_id: @entitlement.booking_id,
          event_id: @entitlement.booking.event_id,
          qr_token: @entitlement.qr_token,
          url: "vibes://bookings/#{@entitlement.booking_id}/tickets/#{@entitlement.id}"
        }.to_json

        qr = RQRCode::QRCode.new(payload)
        size = [params[:size].to_i, 1000].min
        size = 300 if size <= 0

        png = qr.as_png(
          bit_depth: 1,
          border_modules: 4,
          color_mode: ChunkyPNG::COLOR_GRAYSCALE,
          color: 'black',
          file: nil,
          fill: 'white',
          module_px_size: 6,
          resize_exactly_to: false,
          resize_gte_to: false,
          size: size
        )

        if params[:format] == 'image'
          send_data png.to_s, type: 'image/png', disposition: 'inline',
                              filename: "ticket_#{@entitlement.id}.png"
          return
        end

        api_success(
          data: {
            qr_code: Base64.strict_encode64(png.to_s),
            qr_image_url: "#{request.base_url}/api/v1/ticket_entitlements/#{@entitlement.id}/qr?format=image&size=#{size}",
            payload: JSON.parse(payload),
            ticket: entitlement_response(@entitlement, @entitlement.booking)
          },
          status: :ok
        )
      end

      # POST /api/v1/ticket_entitlements/:id/invite
      # Assign ticket to another user by email (they claim in app when they sign up / log in)
      def invite
        unless @entitlement.purchaser_id == current_user.id
          api_error(message: 'Only the purchaser can assign invites', status: :forbidden)
          return
        end

        email = params[:email].to_s.strip.downcase
        if email.blank?
          api_error(message: 'email is required', status: :bad_request)
          return
        end

        user = User.find_by('LOWER(email) = ?', email)
        if user
          @entitlement.update!(holder_id: user.id, invited_email: email, invited_at: Time.current, invite_token: nil)
          api_success(data: { ticket: entitlement_response(@entitlement.reload, @entitlement.booking) }, message: 'Ticket assigned', status: :ok)
        else
          token = SecureRandom.urlsafe_base64(24)
          @entitlement.update!(invited_email: email, invited_at: Time.current, invite_token: token, holder_id: nil)
          api_success(
            data: {
              ticket: entitlement_response(@entitlement.reload, @entitlement.booking),
              invite_token: token,
              claim_url: "#{request.base_url}/api/v1/ticket_entitlements/claim?token=#{token}"
            },
            message: 'Invite recorded. User can claim with token when they join.',
            status: :ok
          )
        end
      end

      # POST /api/v1/ticket_entitlements/claim?token=
      def claim
        token = params[:token].to_s
        if token.blank?
          api_error(message: 'token is required', status: :bad_request)
          return
        end

        ent = TicketEntitlement.find_by(invite_token: token)
        unless ent
          api_error(message: 'Invalid or expired invite', status: :not_found)
          return
        end

        ent.update!(holder_id: current_user.id, invite_token: nil)
        api_success(data: { ticket: entitlement_response(ent.reload, ent.booking) }, message: 'Ticket claimed', status: :ok)
      end

      private

      def set_entitlement
        @entitlement = TicketEntitlement.find_by(id: params[:id])
        api_error(message: 'Ticket not found', status: :not_found) unless @entitlement
      end

      def can_view_booking?(booking)
        booking.user_id == current_user.id ||
          current_user.role_admin? ||
          booking.event.creator_id == current_user.id ||
          booking.event.venue&.owner_id == current_user.id
      end

      def can_view_entitlement?(ent)
        ent.purchaser_id == current_user.id ||
          ent.holder_id == current_user.id ||
          current_user.role_admin? ||
          ent.booking.event.creator_id == current_user.id ||
          ent.booking.event.venue&.owner_id == current_user.id
      end

      def entitlement_response(ent, booking, include_event: false, request: nil)
        ev = booking.event
        base = {
          id: ent.id,
          status: ent.status,
          qr_token: ent.status_active? || ent.status_checked_in? ? ent.qr_token : nil,
          position: ent.position,
          ticket_type: {
            id: ent.event_ticket_type_id,
            name: ent.event_ticket_type.name,
            price: ent.event_ticket_type.price.to_f
          },
          purchaser_id: ent.purchaser_id,
          holder_id: ent.holder_id,
          invited_email: ent.invited_email,
          checked_in_at: ent.checked_in_at&.iso8601,
          booking_id: booking.id,
          event_id: booking.event_id
        }
        if include_event && ev
          base[:event] = {
            id: ev.id,
            title: ev.title,
            starts_at: ev.starts_at&.iso8601,
            ends_at: ev.ends_at&.iso8601,
            timezone: ev.timezone,
            venue: ev.venue ? { id: ev.venue.id, name: ev.venue.name, city: ev.venue.city } : nil,
            poster_url: ev.poster_image_url(host: request&.base_url)&.to_s
          }
          if request && (ent.status_active? || ent.status_checked_in?)
            base[:qr_url] = "#{request.base_url}/api/v1/ticket_entitlements/#{ent.id}/qr"
          end
        end
        base
      end
    end
  end
end
