module Api
  module V1
    class BookingsController < ApplicationController
      include PrChatUsersHelpers

      # Eager-load for booking_response (ticket tiers, event, preorders) without N+1 queries.
      BOOKING_RESPONSE_INCLUDES = [
        :user,
        { booking_ticket_lines: :event_ticket_type },
        { ticket_entitlements: :event_ticket_type },
        { event: [:venue, :event_ticket_types, { photos_attachments: :blob }] },
        { food_bar_orders: { food_bar_order_items: :menu_item } }
      ].freeze

      before_action :require_authentication!
      before_action :set_event, only: [:index, :create, :my_booking, :occupied_tables]
      before_action :set_booking, only: [:show, :update, :cancel, :check_in, :check_out, :pay, :create_payment_intent, :cancellation_info, :share_qr, :assign_table, :update_preorder, :add_preorder_item, :update_preorder_item, :remove_preorder_item, :payment_details, :pr_chat_users]
      before_action :check_booking_ownership, only: [:cancel, :cancellation_info, :update_preorder, :add_preorder_item, :update_preorder_item, :remove_preorder_item]
      before_action :check_venue_ownership, only: [:check_in, :check_out]
      
      # GET /api/v1/events/:event_id/bookings
      def index
        # Event creator, venue owner, admin, or active PR for the host venue
        unless @event.creator_id == current_user.id ||
               @event.venue&.owner_id == current_user.id ||
               current_user.role_admin? ||
               (@event.venue_id.present? && current_user.active_pr_partnerships.exists?(venue_id: @event.venue_id))
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        bookings = @event.bookings.visible_in_listings.includes(BOOKING_RESPONSE_INCLUDES)
        
        # Filter by status
        bookings = bookings.where(status: params[:status]) if params[:status].present?
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = bookings.count
        bookings = bookings.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            event: {
              id: @event.id,
              title: @event.title,
              bookings_count: @event.bookings_count
            },
            bookings: bookings.map { |booking| booking_response(booking) },
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

      # GET /api/v1/events/:event_id/bookings/occupied_tables
      def occupied_tables
        bookings = @event.bookings
                         .where(status: %w[created confirmed checked_in])
                         .where.not(table_number: nil)
        if params[:booking_id].present?
          bookings = bookings.where.not(id: params[:booking_id])
        end

        api_success(
          data: { table_numbers: bookings.pluck(:table_number).uniq },
          status: :ok
        )
      end
      
      # GET /api/v1/events/:event_id/bookings/my_booking
      def my_booking
        booking = @event.bookings
                       .visible_in_listings
                       .includes(BOOKING_RESPONSE_INCLUDES)
                        .find_by(user: current_user)
        if booking
          api_success(
            data: { booking: booking_response(booking, include_event: true, include_preorder: true) },
            status: :ok
          )
        else
          api_success(data: { booking: nil }, message: 'You have not booked this event', status: :ok)
        end
      end
      
      # GET /api/v1/bookings/:id
      def show
        unless can_view_booking?(@booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          status: :ok
        )
      end

      # GET /api/v1/bookings/:id/payment_details
      # Returns detailed payment view for UI: base price, discounts, pre-booking info,
      # preorder totals, and current payment progress.
      def payment_details
        unless can_view_booking?(@booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        event = @booking.event

        preorder_total = @booking.food_bar_orders.sum(:total_amount)

        data = {
          booking_id: @booking.id,
          event: {
            id: event.id,
            title: event.title,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            currency: event.currency || @booking.currency,
            has_pre_booking: event.has_pre_booking?,
            pre_booking_active: event.pre_booking_active?,
            pre_booking_price: event.pre_booking_price&.to_f,
            pre_booking_deadline: event.pre_booking_deadline&.iso8601,
            current_price: event.current_price&.to_f
          },
          pricing: {
            original_price: @booking.original_price&.to_f || @booking.price.to_f,
            discount_amount: @booking.discount_amount&.to_f || 0.0,
            promo_code: @booking.promo_code,
            booking_price: @booking.price.to_f,
            preorder_total: preorder_total.to_f,
            total_with_preorders: @booking.total_price_with_preorders,
            fees: platform_fees_breakdown(@booking.remaining_amount)
          },
          payment: {
            currency: @booking.currency,
            payment_status: @booking.payment_status,
            payment_type: @booking.payment_type,
            paid_amount: @booking.paid_amount.to_f,
            remaining_amount: @booking.remaining_amount.to_f,
            payment_progress_percentage: @booking.payment_progress_percentage,
            fully_paid: @booking.fully_paid?,
            partially_paid: @booking.partially_paid?,
            requires_payment: @booking.requires_payment?,
            is_free: @booking.free?,
            paid_at: @booking.paid_at&.iso8601
          }
        }

        api_success(
          data: { payment_details: data },
          status: :ok
        )
      end

      # GET /api/v1/bookings/:id/pr_chat_users
      # Same PR list as GET /api/v1/events/:event_id/pr_chat_users, scoped to a booking you can view.
      def pr_chat_users
        unless can_view_booking?(@booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        event = @booking.event
        unless can_access_event_pr_chat_users?(event)
          api_error(message: 'You do not have access to PR contacts for this event', status: :forbidden)
          return
        end

        payload = pr_chat_users_payload_for_venue(event.venue)
        success_opts = {
          data: payload.merge(
            event_id: event.id.to_s,
            booking_id: @booking.id.to_s
          ),
          status: :ok
        }
        success_opts[:message] = 'No active PR users for this event’s venue' unless payload[:pr_users].any?
        api_success(**success_opts)
      end

      # PATCH /api/v1/bookings/:id
      # Update booking details and (optionally) attendee counts.
      # When attendee counts change, booking price is recalculated from event pricing,
      # but only while payment_status is pending (to avoid breaking payment history).
      #
      # Active PR for the event's host venue can view/update bookings (they no longer use PATCH /events/:id for that).
      # While payment is pending, PR may set booking `price` for non–ticket-line bookings (RSVP-style); tiered events keep price on ticket lines.
      def update
        unless can_view_booking?(@booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        ticket_lines = ticket_lines_in_request? ? parse_ticket_lines_param : nil
        return if ticket_lines_in_request? && ticket_lines.nil?

        permitted = params.require(:booking).permit(
          :notes,
          :table_number,
          :adults_count,
          :children_count,
          :infants_count,
          :pets_count,
          :price
        )

        # Normalize empty table_number to nil
        if permitted.key?(:table_number)
          permitted[:table_number] = permitted[:table_number].presence
        end

        # If attendee counts are being changed, validate and possibly recalculate price
        counts_changed = %i[adults_count children_count infants_count pets_count].any? { |k| permitted.key?(k) }

        if counts_changed
          if !@booking.payment_status_pending?
            api_error(message: 'Cannot change attendee counts after payment has started', status: :bad_request)
            return
          end

          counts = {
            adults: (permitted[:adults_count] || @booking.adults_count).to_i,
            children: (permitted[:children_count] || @booking.children_count).to_i,
            infants: (permitted[:infants_count] || @booking.infants_count).to_i,
            pets: (permitted[:pets_count] || @booking.pets_count).to_i
          }

          unless valid_attendee_counts?(counts)
            api_error(message: 'Attendee counts must be non-negative and total greater than 0', status: :bad_request)
            return
          end

          # Recalculate price from event pricing
          new_price = calculate_booking_price(@booking.event, counts)
          permitted[:price] = new_price
          permitted[:adults_count] = counts[:adults]
          permitted[:children_count] = counts[:children]
          permitted[:infants_count] = counts[:infants]
          permitted[:pets_count] = counts[:pets]
        elsif can_adjust_booking_price?(@booking) && @booking.payment_status_pending?
          # Venue-side users (owner/manager/PR) can adjust RSVP-style booking price here.
          # Tiered ticket bookings use ticket_lines instead of direct booking price edits.
          raw = params[:booking]
          if raw.present?
            price_value =
              if raw.respond_to?(:key?) && (raw.key?(:price) || raw.key?('price'))
                raw[:price] || raw['price']
              end
            permitted[:price] = price_value.to_d if price_value.present?
          end
        end

        if ticket_lines.present?
          # Allow ticket-line changes only before payment starts.
          # Legacy/incorrect flows could create a tickets booking with payment_status=paid and price=0
          # (no payment_transaction). Treat that as "not started" so we can convert it into a ticket-lines booking.
          unless @booking.paid_amount.to_d.zero? && @booking.payment_transaction_id.nil?
            api_error(message: 'Cannot change ticket lines after payment has started', status: :bad_request)
            return
          end

          begin
            ApplicationRecord.transaction do
              update_ticket_lines_for_booking!(@booking, ticket_lines)
              # Ticket-line bookings control price via ticket lines; ignore direct price edits.
              @booking.update!(permitted.except(:price))
            end
          rescue ArgumentError => e
            api_error(message: e.message, status: :bad_request)
            return
          rescue ActiveRecord::RecordInvalid => e
            api_validation_error(errors: e.record.errors.full_messages)
            return
          end

          @booking = Booking.includes(BOOKING_RESPONSE_INCLUDES).find(@booking.id)
          BookingBroadcaster.price_updated(@booking)
          api_success(
            data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
            message: 'Booking updated successfully',
            status: :ok
          )
          return
        end

        if @booking.update(permitted)
          @booking = Booking.includes(BOOKING_RESPONSE_INCLUDES).find(@booking.id)
          BookingBroadcaster.status_updated(@booking)
          api_success(
            data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
            message: 'Booking updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @booking.errors.full_messages)
        end
      end
      
      # GET /api/v1/bookings/my_bookings
      def my_bookings
        bookings = current_user.bookings.includes(BOOKING_RESPONSE_INCLUDES).visible_in_listings
        
        # Filter by status
        bookings = bookings.where(status: params[:status]) if params[:status].present?
        
        # Filter by time
        case params[:time_filter]
        when 'upcoming'
          bookings = bookings.upcoming
        when 'past'
          bookings = bookings.past
        end
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = bookings.count
        bookings = bookings.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            bookings: bookings.map { |booking| booking_response(booking, include_event: true) },
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

      # PATCH /api/v1/bookings/:id/preorder
      def update_preorder
        pre_order_params = params[:pre_order] || {}
        items_params = pre_order_params[:items] || pre_order_params['items']
        items_provided = items_params.is_a?(Array) && items_params.any?

        raw_start = pre_order_params[:time_window_start] || pre_order_params['time_window_start']
        raw_end = pre_order_params[:time_window_end] || pre_order_params['time_window_end']
        time_window_start = raw_start.present? ? parse_time_param(raw_start) : nil
        time_window_end = raw_end.present? ? parse_time_param(raw_end) : nil
        if time_window_start == :invalid || time_window_end == :invalid
          api_error(message: 'Invalid pre-order time window', status: :bad_request)
          return
        end

        if items_provided
          unless ensure_event_menus_from_venue!(@booking.event)
            api_error(message: 'No menu available for this event', status: :bad_request)
            return
          end

          preorder_error = validate_preorder_items(@booking.event, items_params)
          if preorder_error
            api_error(message: preorder_error, status: :bad_request)
            return
          end
        end

        order = @booking.food_bar_orders.order(created_at: :desc).first
        unless order
          order = create_preorder(
            @booking.event,
            @booking,
            pre_order_params,
            time_window_start: time_window_start,
            time_window_end: time_window_end
          )
          unless order
            preorder_error = @preorder_error&.join(', ') || 'Failed to create pre-order'
            api_error(message: preorder_error, status: :unprocessable_entity)
            return
          end

          api_success(
            data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
            message: 'Pre-order updated successfully',
            status: :ok
          )
          return
        end

        unless order.status_pending? && order.payment_pending?
          api_error(message: 'Pre-order cannot be modified at this stage', status: :unprocessable_entity)
          return
        end

        FoodBarOrder.transaction do
          order.assign_attributes(
            order_type: pre_order_params[:order_type] || pre_order_params['order_type'] || order.order_type,
            table_number: pre_order_params[:table_number] || pre_order_params['table_number'] || order.table_number,
            special_instructions: pre_order_params[:special_instructions] || pre_order_params['special_instructions'],
            allergies: pre_order_params[:allergies] || pre_order_params['allergies'],
            dietary_restrictions: pre_order_params[:dietary_restrictions] || pre_order_params['dietary_restrictions']
          )

          if pre_order_params.key?(:tip_amount) || pre_order_params.key?('tip_amount')
            order.tip_amount = pre_order_params[:tip_amount]&.to_f || pre_order_params['tip_amount']&.to_f || 0
          end

          if pre_order_params.key?(:tip_percentage) || pre_order_params.key?('tip_percentage')
            order.tip_percentage = pre_order_params[:tip_percentage]&.to_f || pre_order_params['tip_percentage']&.to_f
          end

          order.time_window_start = time_window_start if raw_start.present?
          order.time_window_end = time_window_end if raw_end.present?

          if items_provided
            order.food_bar_order_items.destroy_all
            subtotal = 0
            items_params.each do |item_param|
              menu_item_id = item_param[:menu_item_id] || item_param['menu_item_id']
              menu_item = resolve_menu_item_for_event(@booking.event, menu_item_id)
              unless menu_item
                raise ActiveRecord::Rollback, 'Menu item not found for this event'
              end

              order_item = order.food_bar_order_items.build(
                menu_item: menu_item,
                quantity: item_param[:quantity] || item_param['quantity'] || 1,
                unit_price: menu_item.price,
                special_instructions: item_param[:special_instructions] || item_param['special_instructions'],
                customizations: (item_param[:customizations] || item_param['customizations'])&.to_json
              )

              item_total = order_item.total_price
              if item_total.nil?
                item_total = (order_item.unit_price || menu_item.price) * order_item.quantity
              end
              subtotal += item_total
            end

            order.subtotal = subtotal
            order.tax = (subtotal * 0.08).round(2)
          end
          order.save!
        end

        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          message: 'Pre-order updated successfully',
          status: :ok
        )
      rescue ActiveRecord::Rollback => e
        api_error(message: e.message, status: :unprocessable_entity)
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: e.record.errors.full_messages)
      end

      # POST /api/v1/bookings/:id/preorder/items
      def add_preorder_item
        item_param = params[:item] || {}
        menu_item_id = item_param[:menu_item_id] || item_param['menu_item_id'] || params[:menu_item_id]
        quantity = item_param[:quantity] || item_param['quantity'] || params[:quantity] || 1

        unless quantity.to_i > 0
          api_error(message: 'Quantity must be greater than 0', status: :bad_request)
          return
        end

        unless ensure_event_menus_from_venue!(@booking.event)
          api_error(message: 'No menu available for this event', status: :bad_request)
          return
        end

        item_error = validate_preorder_items(@booking.event, [{ menu_item_id: menu_item_id, quantity: quantity }])
        if item_error
          api_error(message: item_error, status: :bad_request)
          return
        end

        menu_item = resolve_menu_item_for_event(@booking.event, menu_item_id)

        # Try to get a modifiable order (pending status and payment)
        # Use find_modifiable_preorder (no errors) so we can create new if needed
        order = find_modifiable_preorder

        # If no modifiable order exists, create a new one
        if order.nil?
          pre_order_params = params[:pre_order] || {}
          raw_start = pre_order_params[:time_window_start] || pre_order_params['time_window_start']
          raw_end = pre_order_params[:time_window_end] || pre_order_params['time_window_end']
          time_window_start = raw_start.present? ? parse_time_param(raw_start) : nil
          time_window_end = raw_end.present? ? parse_time_param(raw_end) : nil
          if time_window_start == :invalid || time_window_end == :invalid
            api_error(message: 'Invalid pre-order time window', status: :bad_request)
            return
          end

          order = create_preorder(
            @booking.event,
            @booking,
            pre_order_params.merge(items: [{ menu_item_id: menu_item_id, quantity: quantity, special_instructions: item_param[:special_instructions], customizations: item_param[:customizations] }]),
            time_window_start: time_window_start,
            time_window_end: time_window_end
          )

          unless order
            preorder_error = @preorder_error&.join(', ') || 'Failed to create pre-order'
            api_error(message: preorder_error, status: :unprocessable_entity)
            return
          end
        else
          # Add item to existing modifiable order
          existing_item = order.food_bar_order_items.find_by(menu_item_id: menu_item.id)

          FoodBarOrderItem.transaction do
            if existing_item
              existing_item.update!(quantity: existing_item.quantity + quantity.to_i)
            else
              order.food_bar_order_items.create!(
                menu_item: menu_item,
                quantity: quantity.to_i,
                unit_price: menu_item.price,
                special_instructions: item_param[:special_instructions] || item_param['special_instructions'],
                customizations: (item_param[:customizations] || item_param['customizations'])&.to_json
              )
            end
            recalc_preorder_totals!(order)
          end
        end

        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          message: 'Pre-order item added successfully',
          status: :ok
        )
      end

      # PATCH /api/v1/bookings/:id/preorder/items/:item_id
      def update_preorder_item
        order = fetch_modifiable_preorder
        return unless order

        item = order.food_bar_order_items.find_by(id: params[:item_id])
        unless item
          api_error(message: 'Pre-order item not found', status: :not_found)
          return
        end

        quantity = params[:quantity] || params.dig(:item, :quantity) || params.dig('item', 'quantity')
        if quantity.present? && quantity.to_i <= 0
          item.destroy
          recalc_preorder_totals!(order)
          api_success(
            data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
            message: 'Pre-order item removed successfully',
            status: :ok
          )
          return
        end

        item.update!(
          quantity: quantity.present? ? quantity.to_i : item.quantity,
          special_instructions: params[:special_instructions] || params.dig(:item, :special_instructions) || params.dig('item', 'special_instructions') || item.special_instructions,
          customizations: (params[:customizations] || params.dig(:item, :customizations) || params.dig('item', 'customizations'))&.to_json || item.customizations
        )

        recalc_preorder_totals!(order)

        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          message: 'Pre-order item updated successfully',
          status: :ok
        )
      end

      # DELETE /api/v1/bookings/:id/preorder/items/:item_id
      def remove_preorder_item
        order = fetch_modifiable_preorder
        return unless order

        item = order.food_bar_order_items.find_by(id: params[:item_id])
        unless item
          api_error(message: 'Pre-order item not found', status: :not_found)
          return
        end

        item.destroy
        recalc_preorder_totals!(order)

        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          message: 'Pre-order item removed successfully',
          status: :ok
        )
      end

      
      # POST /api/v1/events/:event_id/bookings
      def create
        # Enforce max bookings per user per event
        existing_bookings = @event.bookings.where(user: current_user)
        if existing_bookings.where.not(status: 'canceled').count >= 10
          api_error(message: 'Maximum 10 bookings per user for this event', status: :bad_request)
          return
        end
        
        # Check if event is bookable
        if @event.status_canceled?
          api_error(message: 'Cannot book canceled events', status: :bad_request)
          return
        end
        
        if @event.ends_at < Time.current
          api_error(message: 'Cannot book past events', status: :bad_request)
          return
        end

        # Ticket purchase only while sales are open; after close, same endpoint continues as RSVP.
        # When tickets are open, require ticket_lines so we don't accidentally create an RSVP/free booking
        # for a tickets-mode event (event.price can be 0 while ticket types carry the actual pricing).
        if @event.tickets_mode? && !@event.tickets_closed?
          unless ticket_lines_in_request?
            api_error(message: 'ticket_lines are required for this tickets event', status: :bad_request)
            return
          end
          create_ticket_booking
          return
        end

        # Remove canceled booking records if any
        existing_bookings.where(status: 'canceled').destroy_all if existing_bookings.present?
        
        counts = extract_attendee_counts
        unless valid_attendee_counts?(counts)
          api_error(message: 'Attendee counts must be non-negative and total greater than 0', status: :bad_request)
          return
        end

        table_number = (params[:table_number] || params.dig(:booking, :table_number)).to_s.strip
        if table_number.present?
          table = find_bookable_table_for_booking(@event, table_number)
          unless table
            api_error(message: 'Table not found or not bookable', status: :not_found)
            return
          end
          if Booking.table_occupied_for_event?(@event.id, table_number)
            api_error(message: 'This table is already booked for this event', status: :unprocessable_entity)
            return
          end
        end

        preorder_params = params[:pre_order].presence || params.dig(:booking, :pre_order) || {}
        preorder_items = preorder_params[:items] || preorder_params['items']
        time_window_start = nil
        time_window_end = nil
        if preorder_params.present?
          time_window_start = parse_time_param(preorder_params[:time_window_start] || preorder_params['time_window_start'])
          time_window_end = parse_time_param(preorder_params[:time_window_end] || preorder_params['time_window_end'])
          if time_window_start == :invalid || time_window_end == :invalid
            api_error(message: 'Invalid pre-order time window', status: :bad_request)
            return
          end

          unless preorder_items.is_a?(Array) && preorder_items.any?
            api_error(message: 'Pre-order items are required', status: :bad_request)
            return
          end

          unless ensure_event_menus_from_venue!(@event)
            api_error(message: 'No menu available for this event', status: :bad_request)
            return
          end

          preorder_error = validate_preorder_items(@event, preorder_items)
          if preorder_error
            api_error(message: preorder_error, status: :bad_request)
            return
          end
        end

        if @event.age_pricing_enabled?
          missing_prices = []
          missing_prices << 'adult_price' if counts[:adults] > 0 && @event.adult_price.nil?
          missing_prices << 'child_price' if counts[:children] > 0 && @event.child_price.nil?
          missing_prices << 'infant_price' if counts[:infants] > 0 && @event.infant_price.nil?
          missing_prices << 'pet_price' if counts[:pets] > 0 && @event.pet_price.nil?

          if missing_prices.any?
            api_error(
              message: "Missing pricing for: #{missing_prices.join(', ')}",
              status: :bad_request
            )
            return
          end
        end
        
        # Determine booking price
        price = calculate_booking_price(@event, counts)
        currency = @event.currency.presence || 'USD'
        is_free = @event.free?
        # All bookings (free and paid) start as 'created' - venue/brand must approve via approve_booking.
        # Free bookings stay 'created' until venue confirms; paid bookings stay 'created' until paid AND venue confirms.
        status = 'created'
        payment_status = is_free ? 'paid' : 'pending'
        promo_param = params[:promo_code].presence || params.dig(:booking, :promo_code)
        promo_result = apply_promo_to_price(price, currency, @event, promo_param)
        if promo_result[:error]
          api_error(message: promo_result[:error], status: :unprocessable_entity)
          return
        end
        price = promo_result[:final_price]
        if price.to_f <= 0
          payment_status = 'paid'
        end
        
        # Create booking
        booking = @event.bookings.build(
          user: current_user,
          status: status,
          price: price,
          currency: currency,
          payment_status: payment_status,
          payment_method: params[:payment_method].presence || params.dig(:booking, :payment_method),
          adults_count: counts[:adults],
          children_count: counts[:children],
          infants_count: counts[:infants],
          pets_count: counts[:pets],
          table_number: table_number.presence,
          assigned_by_id: table_number.present? ? current_user.id : nil,
          table_assigned_at: table_number.present? ? Time.current : nil,
          promo_code_id: promo_result[:promo_code_id],
          promo_code: promo_result[:promo_code],
          original_price: promo_result[:original_price],
          discount_amount: promo_result[:discount_amount]
        )
        
        if booking.save
          preorder = nil
          if preorder_params.present?
          preorder = create_preorder(
              @event,
              booking,
              preorder_params,
              time_window_start: time_window_start,
              time_window_end: time_window_end
            )
            unless preorder
            preorder_error = @preorder_error&.join(', ') || 'Failed to create pre-order'
            api_error(message: preorder_error, status: :unprocessable_entity)
              return
            end
          end

        # Notify venue team (owner + PR + managers) that a booking was created and needs approval.
        BookingNotificationService.notify_venue_for_booking_request(booking)

          booking = Booking.includes(BOOKING_RESPONSE_INCLUDES).find(booking.id)
          response_data = { booking: booking_response(booking) }
          response_data[:preorder] = preorder_response(preorder) if preorder

          api_success(
            data: response_data,
            message: is_free ? 'Booking created. Waiting for venue to approve.' : 'Booking created. Payment required.',
            status: :created
          )
        else
          api_validation_error(errors: booking.errors.full_messages)
        end
      end
      
      # POST /api/v1/bookings/:id/pay
      def pay
        if @booking.payment_status_paid? && @booking.fully_paid?
          api_error(message: 'Booking is already fully paid', status: :bad_request)
          return
        end
        
        if @booking.status_canceled?
          api_error(message: 'Cannot pay for canceled booking', status: :bad_request)
          return
        end
        
        # Get payment amount (optional, defaults to remaining amount)
        payment_amount = params[:amount]&.to_d
        payment_type = params[:payment_type] # 'pre_payment', 'partial', 'full', 'overpayment'
        
        remaining = @booking.remaining_amount
        
        # If amount not provided, use remaining amount (full payment)
        payment_amount ||= remaining
        
        # Validate amount
        unless payment_amount > 0
          api_error(message: 'Payment amount must be greater than 0', status: :bad_request)
          return
        end
        
        # Determine payment type if not provided
        if payment_type.nil?
          if payment_amount >= remaining
            payment_type = payment_amount > remaining ? 'overpayment' : 'full'
          else
            payment_type = 'partial'
          end
        end
        
        # Process payment with specified amount
        payment_result = process_booking_payment(@booking, params.merge(amount: payment_amount, payment_type: payment_type))
        
        if payment_result[:success]
          @booking.mark_as_paid!(payment_result[:transaction], amount: payment_amount)

          # Paid events: notify venue for RSVP approve/reject (venue must confirm booking)
          if @booking.fully_paid? && @booking.status_created?
            BookingNotificationService.notify_venue_for_booking_request(@booking)
          end

          BookingBroadcaster.payment_completed(@booking, amount: payment_amount)
          
          api_success(
            data: { 
              booking: booking_response(@booking),
              payment_info: {
                amount_paid: payment_amount.to_f,
                payment_type: payment_type,
                remaining_amount: @booking.remaining_amount.to_f,
                payment_progress: @booking.payment_progress_percentage
              }
            },
            message: payment_type == 'partial' ? 'Partial payment processed successfully' : 'Payment processed successfully',
            status: :ok
          )
        else
          @booking.mark_payment_failed!
          BookingBroadcaster.payment_failed(@booking)
          api_error(
            message: payment_result[:error] || 'Payment processing failed',
            data: { booking: booking_response(@booking) },
            status: :unprocessable_entity
          )
        end
      end

      # POST /api/v1/bookings/:id/create_payment_intent (for Flutter)
      def create_payment_intent
        if @booking.payment_status_paid? && @booking.fully_paid?
          api_error(message: 'Booking is already fully paid', status: :bad_request)
          return
        end
        
        if @booking.status_canceled?
          api_error(message: 'Cannot pay for canceled booking', status: :bad_request)
          return
        end

        if @booking.free? && @booking.price.to_d.zero?
          api_error(message: 'This booking is free and does not require payment', status: :bad_request)
          return
        end

        provider = params[:provider] || 'stripe'
        customer_id = params[:customer_id]
        payment_method_id = params[:payment_method_id]
        
        # Determine payment amount and type
        payment_amount = params[:amount]&.to_d
        payment_type_param = params[:payment_type] # 'pre_payment', 'partial', 'full', 'overpayment'
        
        booking_price = @booking.price.to_d
        remaining = @booking.remaining_amount
        
        # If amount not provided, use remaining amount (full payment)
        if payment_amount.nil?
          payment_amount = remaining
          payment_type_param = 'full'
        end
        
        # Validate amount
        unless payment_amount > 0
          api_error(message: 'Payment amount must be greater than 0', status: :bad_request)
          return
        end
        
        # Determine payment type based on amount
        if payment_type_param.nil?
          if payment_amount >= remaining
            payment_type_param = payment_amount > remaining ? 'overpayment' : 'full'
          else
            payment_type_param = 'partial'
          end
        end
        
        # Validate payment type logic
        case payment_type_param
        when 'pre_payment'
          # Pre-payment: paying before full booking is confirmed (deposit)
          # Amount can be less than booking price
        when 'partial'
          if payment_amount >= remaining
            api_error(message: "Partial payment amount (#{payment_amount}) must be less than remaining amount (#{remaining})", status: :bad_request)
            return
          end
        when 'full'
          unless (payment_amount - remaining).abs <= 0.01 # Allow 1 cent tolerance
            api_error(message: "Full payment amount (#{payment_amount}) must match remaining amount (#{remaining})", status: :bad_request)
            return
          end
        when 'overpayment'
          if payment_amount <= remaining
            api_error(message: "Overpayment amount (#{payment_amount}) must be greater than remaining amount (#{remaining})", status: :bad_request)
            return
          end
        else
          api_error(message: "Invalid payment_type. Must be one of: pre_payment, partial, full, overpayment", status: :bad_request)
          return
        end

        # Create PaymentTransaction record
        wallet = current_user.wallets.find_or_create_by!(currency: @booking.currency) do |w|
          w.status = 'active'
          w.balance = 0
          w.locked_balance = 0
        end

        transaction = PaymentTransaction.create!(
          wallet: wallet,
          user: current_user,
          transaction_type: 'payment',
          status: 'pending',
          amount: payment_amount,
          currency: @booking.currency,
          payment_method: 'credit_card', # Default, can be updated later
          payment_provider: provider,
          reference: @booking,
          metadata: {
            event_id: @booking.event.id,
            event_title: @booking.event.title,
            booking_id: @booking.id,
            payment_type: payment_type_param,
            booking_price: booking_price.to_f,
            remaining_amount: remaining.to_f,
            current_paid_amount: @booking.paid_amount.to_f
          }.to_json
        )

        # Create Payment Intent via Stripe
        provider_config = PaymentProvider.active_lookup(provider)
        unless provider_config
          api_error(message: "Payment provider '#{provider}' not found or inactive", status: :bad_request)
          return
        end

        stripe_provider = StripePaymentProvider.new(provider_config)

        result = stripe_provider.create_payment_intent(
          amount: payment_amount,
          currency: @booking.currency,
          transaction_id: transaction.id,
          metadata: {
            user_id: current_user.id,
            booking_id: @booking.id,
            event_id: @booking.event.id,
            event_title: @booking.event.title,
            payment_type: payment_type_param,
            booking_price: booking_price.to_f,
            remaining_amount: remaining.to_f
          },
          customer_id: customer_id,
          payment_method_id: payment_method_id
        )

        # Update transaction with payment intent ID
        transaction.update!(
          provider_transaction_id: result[:payment_intent_id],
          provider_response: result.to_json
        )

        # User-side fees for display
        fees = platform_fees_breakdown(payment_amount)

        api_success(
          data: {
            payment_intent_id: result[:payment_intent_id],
            client_secret: result[:client_secret],
            transaction_id: transaction.id,
            booking_id: @booking.id,
            amount: result[:amount],
            currency: result[:currency],
            status: result[:status],
            payment_type: payment_type_param,
            booking_price: booking_price.to_f,
            booking_currency: @booking.currency,
            remaining_amount: remaining.to_f,
            current_paid_amount: @booking.paid_amount.to_f,
            original_price: @booking.original_price&.to_f,
            discount_amount: @booking.discount_amount&.to_f,
            promo_code: @booking.promo_code,
            fees: fees
          },
          message: 'Payment intent created successfully',
          status: :created
        )
      rescue PaymentService::InvalidProviderError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        transaction&.update!(status: 'failed', description: e.message)
        api_error(message: "Failed to create payment intent: #{e.message}", status: :unprocessable_entity)
      end
      
      # POST /api/v1/bookings/:id/request_cancellation
      def request_cancellation
        unless @booking.can_cancel?
          api_error(message: 'Booking cannot be canceled', status: :bad_request)
          return
        end
        
        if @booking.pending_cancellation?
          api_error(message: 'Cancellation already requested', status: :bad_request)
          return
        end
        
        reason = params[:reason] || params[:cancellation_reason]
        @booking.request_cancellation!(reason: reason)
        
        api_success(
          data: { 
            booking: booking_response(@booking),
            cancellation_info: {
              status: 'pending_approval',
              requested_at: @booking.cancellation_requested_at.iso8601,
              refund_amount: @booking.cancellation_refund_amount.to_f,
              cancellation_fee: @booking.cancellation_fee_amount.to_f
            }
          },
          message: 'Cancellation request submitted. Waiting for venue approval.',
          status: :ok
        )
      end
      
      # POST /api/v1/bookings/:id/cancel (Direct cancel - for free events or auto-approve)
      def cancel
        unless @booking.can_cancel?
          api_error(message: 'Booking cannot be canceled', status: :bad_request)
          return
        end
        reason = params[:reason] || params[:description]

        # Auto-approve for free events
        if @booking.free?
          @booking.update!(
            status: 'canceled',
            canceled_at: Time.current,
            cancellation_reason: reason
          )
        else
          # Request cancellation (needs venue approval)
          return request_cancellation
        end
        
        api_success(
          data: { 
            booking: booking_response(@booking)
          },
          message: 'Booking canceled successfully',
          status: :ok
        )
      end
      
      # GET /api/v1/bookings/:id/cancellation_info
      def cancellation_info
        unless @booking.can_cancel?
          api_error(message: 'Booking cannot be canceled', status: :bad_request)
          return
        end
        
        api_success(
          data: { cancellation_info: @booking.cancellation_info },
          status: :ok
        )
      end
      
      # POST /api/v1/bookings/:id/check_in
      def check_in
        unless @booking.can_check_in?
          api_error(message: 'Only confirmed and paid bookings can be checked in', status: :bad_request)
          return
        end
        
        @booking.check_in!
        BookingBroadcaster.check_in(@booking)
        api_success(
          data: { booking: booking_response(@booking) },
          message: 'Checked in successfully',
          status: :ok
        )
      end

      # POST /api/v1/bookings/:id/check_out
      # Free the table when the guest leaves so it can be reused.
      def check_out
        unless @booking.status_checked_in? && @booking.table_number.present?
          api_error(message: 'Only checked-in bookings with an assigned table can check out', status: :bad_request)
          return
        end
        @booking.check_out!
        BookingBroadcaster.check_out(@booking)
        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          message: 'Checked out successfully; table is now available',
          status: :ok
        )
      end

      # POST /api/v1/bookings/:id/assign_table
      def assign_table
        unless can_view_booking?(@booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        table_number = params[:table_number].to_s.strip
        if table_number.blank?
          api_error(message: 'table_number is required', status: :bad_request)
          return
        end

        table = find_bookable_table_for_booking(@booking, table_number)
        unless table
          api_error(message: 'Table not found or not bookable', status: :not_found)
          return
        end
        if Booking.table_occupied_for_event?(@booking.event_id, table_number, exclude_booking_id: @booking.id)
          api_error(message: 'This table is already booked for this event', status: :unprocessable_entity)
          return
        end

        @booking.update!(
          table_number: table_number,
          assigned_by_id: current_user.id,
          table_assigned_at: Time.current
        )

        BookingBroadcaster.table_assigned(@booking, table_number: table_number)

        api_success(
          data: { booking: booking_response(@booking, include_event: true, include_preorder: true) },
          message: "Table #{table_number} assigned successfully",
          status: :ok
        )
      end

      # GET /api/v1/bookings/:id/share_qr
      def share_qr
        unless can_view_booking?(@booking)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        require 'rqrcode'

        booking_url = "vibes://bookings/#{@booking.id}"
        qr_data = {
          type: "Booking",
          booking_id: @booking.id,
          event_id: @booking.event_id,
          url: booking_url
        }.to_json
        qr = RQRCode::QRCode.new(qr_data)

        size = params[:size].to_i
        size = 300 if size <= 0 || size > 1000

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
          send_data png.to_s,
                    type: 'image/png',
                    disposition: 'inline',
                    filename: "booking_#{@booking.id}_qr.png"
          return
        end

        api_success(
          data: {
            qr_code: Base64.strict_encode64(png.to_s),
            qr_image_url: "#{request.base_url}/api/v1/bookings/#{@booking.id}/share_qr?format=image&size=#{size}",
            booking_url: booking_url,
            type: "Booking",
            booking_id: @booking.id,
            event_id: @booking.event_id,
            booking: booking_response(@booking, include_event: true, include_preorder: true)
          },
          status: :ok
        )
      end
      
      private
      
      def create_ticket_booking
        lines = parse_ticket_lines_param
        return if lines.nil?

        currency = @event.currency.presence || 'EUR'
        total_qty = lines.sum { |l| l[:quantity] }
        if total_qty <= 0
          api_error(message: 'Select at least one ticket', status: :bad_request)
          return
        end

        line_records = []
        total_price = 0.to_d

        booking = nil
        ApplicationRecord.transaction do
          lines.each do |l|
            tt = @event.event_ticket_types.lock.find_by(id: l[:event_ticket_type_id])
            unless tt
              raise ArgumentError, 'Invalid or unknown ticket type'
            end
            if tt.quantity_available < l[:quantity]
              raise ArgumentError, "Not enough tickets left for #{tt.name}"
            end
            line_total = tt.price * l[:quantity]
            total_price += line_total
            line_records << { tt: tt, quantity: l[:quantity], unit_price: tt.price, line_total: line_total }
          end

          line_records.each { |rec| rec[:tt].reserve!(rec[:quantity]) }

          is_free = lines.blank?
          payment_status = is_free ? 'paid' : 'pending'

          booking = @event.bookings.build(
            user: current_user,
            status: 'created',
            price: total_price,
            currency: currency,
            payment_status: payment_status,
            payment_method: params[:payment_method],
            adults_count: total_qty,
            children_count: 0,
            infants_count: 0,
            pets_count: 0
          )
          booking.save!

          position = 0
          line_records.each do |rec|
            booking.booking_ticket_lines.create!(
              event_ticket_type: rec[:tt],
              quantity: rec[:quantity],
              unit_price: rec[:unit_price],
              line_total: rec[:line_total]
            )
            rec[:quantity].times do
              booking.ticket_entitlements.create!(
                event_ticket_type: rec[:tt],
                purchaser: current_user,
                holder: current_user,
                status: is_free ? 'active' : 'pending_payment',
                position: position
              )
              position += 1
            end
          end
        end

        if booking.nil?
          api_error(message: 'Could not create booking', status: :unprocessable_entity)
          return
        end

        booking = Booking.includes(BOOKING_RESPONSE_INCLUDES).find(booking.id)

        BookingNotificationService.notify_venue_for_booking_request(booking)

        api_success(
          data: { booking: booking_response(booking, include_event: true, include_preorder: true) },
          message: booking.requires_payment? ? 'Tickets reserved. Complete payment via Stripe / Apple Pay / Google Pay.' : 'Tickets reserved. Waiting for venue approval.',
          status: :created
        )
      rescue ArgumentError => e
        api_error(message: e.message, status: :bad_request)
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: e.record.errors.full_messages)
      end

      def parse_ticket_lines_param
        raw = params[:ticket_lines] || params.dig(:booking, :ticket_lines)
        unless raw.is_a?(Array) && raw.any?
          api_error(message: 'ticket_lines must be a non-empty array of { event_ticket_type_id, quantity }', status: :bad_request)
          return nil
        end

        raw.map do |row|
          row = row.permit(:event_ticket_type_id, :ticket_type_id, :quantity).to_h if row.respond_to?(:permit)
          row = row.stringify_keys
          id = row['event_ticket_type_id'] || row['ticket_type_id']
          q = (row['quantity'] || 1).to_i
          if id.blank? || q <= 0
            api_error(message: 'Each ticket line needs event_ticket_type_id and quantity > 0', status: :bad_request)
            return nil
          end
          { event_ticket_type_id: id, quantity: q }
        end
      end

      def set_event
        event_id = params[:event_id]
        # Fallback: if path has "bookings" (wrong URL like POST /events/bookings), use event_id from body
        event_id = params.dig(:booking, :event_id) if (event_id.blank? || event_id == 'bookings') && params.dig(:booking, :event_id).present?
        @event = Event.find_by(id: event_id)
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def set_booking
        @booking = Booking.includes(BOOKING_RESPONSE_INCLUDES)
                          .find_by(id: params[:id])
        unless @booking
          api_error(message: 'Booking not found', status: :not_found)
          return
        end

        if @booking.user_id == current_user.id && !@booking.visible_in_listings?
          if @booking.expired_pending_hold?
            api_error(
              message: 'Booking hold expired. Please create a new booking.',
              data: { booking_id: @booking.id, expiry_at: @booking.expiry_at&.iso8601 },
              status: :gone
            )
          else
            api_error(message: 'Booking not found', status: :not_found)
          end
          return
        end
      end
      
      def check_booking_ownership
        unless @booking.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'You can only cancel your own bookings', status: :forbidden)
          return
        end
      end
      
      def check_venue_ownership
        unless @booking.event.creator_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only venue owners can check in attendees', status: :forbidden)
          return
        end
      end
      
      def process_booking_payment(booking, params)
        payment_service = PaymentService.new(current_user, params[:provider])
        
        # Use provided amount or remaining amount
        payment_amount = params[:amount]&.to_d || booking.remaining_amount
        payment_type = params[:payment_type] || 'full'
        
        payment_service.process_payment(
          amount: payment_amount,
          currency: booking.currency,
          payment_method: params[:payment_method] || booking.payment_method,
          reference: booking,
          metadata: {
            event_id: booking.event.id,
            event_title: booking.event.title,
            booking_id: booking.id,
            payment_type: payment_type,
            booking_price: booking.price.to_f,
            remaining_amount: booking.remaining_amount.to_f,
            current_paid_amount: booking.paid_amount.to_f
          }
        )
      end
      
      # Full tier payload (aligned with GET .../events/:id/ticket_types list items).
      def ticket_type_detail_payload(event_ticket_type, event)
        return nil unless event_ticket_type

        {
          id: event_ticket_type.id.to_s,
          name: event_ticket_type.name,
          price: event_ticket_type.price.to_f,
          currency: event_ticket_type.currency.presence || event&.currency,
          quantity_total: event_ticket_type.quantity_total,
          quantity_sold: event_ticket_type.quantity_sold,
          quantity_available: event_ticket_type.quantity_available,
          display_order: event_ticket_type.display_order
        }
      end

      def platform_fees_breakdown(amount)
        base = amount.to_d
        return {} if base <= 0
        rsvp = PlatformFees.rsvp_platform_fee(base).to_f
        stripe = PlatformFees.stripe_processing_fee(base).to_f
        {
          stripe_processing_fee: stripe,
          rsvp_platform_fee: rsvp,
          rsvp_platform_fee_percentage: PlatformFees::RSVP_PLATFORM_FEE_PERCENTAGE,
          total_fees: (rsvp + stripe),
          total_with_fees: PlatformFees.user_total_amount(base).to_f
        }
      end

      def booking_response(booking, include_event: false, include_preorder: false)
        response = {
          id: booking.id,
          chat_id: booking_assigned_pr_chat_id(booking),
          status: booking.status,
          price: booking.price.to_f,
          total_price: booking.total_price_with_preorders,
          original_price: booking.original_price&.to_f,
          discount_amount: booking.discount_amount&.to_f,
          promo_code: booking.promo_code,
          currency: booking.currency,
          payment_status: booking.payment_status,
          payment_type: booking.payment_type,
          paid_amount: booking.paid_amount.to_f,
          remaining_amount: booking.remaining_amount.to_f,
          payment_progress_percentage: booking.payment_progress_percentage,
          fully_paid: booking.fully_paid?,
          partially_paid: booking.partially_paid?,
          payment_method: booking.payment_method,
          paid_at: booking.paid_at&.iso8601,
          is_free: booking.free?,
          requires_payment: booking.requires_payment?,
          checked_in_at: booking.checked_in_at&.iso8601,
          notes: booking.notes,
          table_number: booking.table_number,
          attendees: {
            adults_count: booking.adults_count,
            children_count: booking.children_count,
            infants_count: booking.infants_count,
            pets_count: booking.pets_count,
            total_count: booking.total_attendees_count
          },
          ticket_lines: booking.ticket_booking? ? booking.booking_ticket_lines.map { |l|
            tt = l.event_ticket_type
            {
              event_ticket_type_id: l.event_ticket_type_id,
              ticket_type: ticket_type_detail_payload(tt, booking.event),
              quantity: l.quantity,
              unit_price: l.unit_price.to_f,
              line_total: l.line_total.to_f
            }
          } : nil,
          tickets: booking.ticket_booking? ? booking.ticket_entitlements.order(:position).map { |e|
            tt = e.event_ticket_type
            {
              id: e.id,
              status: e.status,
              position: e.position,
              ticket_type_id: e.event_ticket_type_id,
              ticket_name: tt&.name,
              ticket_type: ticket_type_detail_payload(tt, booking.event),
              holder_id: e.holder_id,
              purchaser_id: e.purchaser_id,
              qr_url: (e.status_active? || e.status_checked_in?) ? "#{request&.base_url}/api/v1/ticket_entitlements/#{e.id}/qr" : nil
            }
          } : nil,
          user: {
            id: booking.user.id,
            name: booking.user.name,
            email: booking.user.email
          },
          cancellation: {
            requested: booking.cancellation_requested,
            requested_at: booking.cancellation_requested_at&.iso8601,
            reason: booking.cancellation_reason,
            approved: booking.cancellation_approved,
            approved_at: booking.cancellation_approved_at&.iso8601,
            rejected_reason: booking.cancellation_rejected_reason
          },
          expiry_at: booking.expiry_at&.iso8601,
          created_at: booking.created_at.iso8601,
          updated_at: booking.updated_at.iso8601,
          has_assignee: booking.assigned_pr_user_id.present?,
          is_assigned_to_current_user: current_user.present? && booking.assigned_pr_user_id == current_user.id,
          venue_approval_status: booking.venue_approval_status_label
        }.merge(booking.api_flow_context)

        response[:assigned_pr] =
          if booking.assigned_pr_user
            venue = booking.event&.venue
            assignment_type =
              if venue && VenuePrPartnership.active.exists?(venue_id: venue.id, user_id: booking.assigned_pr_user.id)
                'pr'
              elsif booking.assigned_pr_user.role_venue_manager?
                'venue_manager'
              elsif venue && VenueStaff.active.by_role('manager').exists?(venue_id: venue.id, user_id: booking.assigned_pr_user.id)
                'venue_manager'
              else
                'user'
              end
            {
              user: {
                id: booking.assigned_pr_user.id,
                name: booking.assigned_pr_user.name,
                username: booking.assigned_pr_user.username,
                role: booking.assigned_pr_user.role
              },
              assignment_type: assignment_type,
              is_current_user_assignee: current_user.present? && booking.assigned_pr_user.id == current_user.id,
              assigned_at: booking.assigned_pr_assigned_at&.iso8601,
              assigned_by: booking.assigned_pr_assigned_by ? { id: booking.assigned_pr_assigned_by.id, name: booking.assigned_pr_assigned_by.name } : nil
            }
          else
            nil
          end
        
        # Include cancellation info if booking was canceled
        if booking.status_canceled?
          response.merge!(
            canceled_at: booking.canceled_at&.iso8601,
            refund_amount: booking.refund_amount&.to_f,
            cancellation_fee: booking.cancellation_fee&.to_f
          )
        end
        
        # Include cancellation policy if booking can be canceled
        if booking.can_cancel?
          response[:cancellation_info] = booking.cancellation_info
        end

        if booking.event.age_pricing_enabled?
          response[:age_pricing] = {
            adult_price: booking.event.adult_price&.to_f,
            child_price: booking.event.child_price&.to_f,
            infant_price: booking.event.infant_price&.to_f,
            pet_price: booking.event.pet_price&.to_f
          }
        end
        
        if include_event
          ev = booking.event
          base_url = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
          response[:event] = {
            id: ev.id,
            title: ev.title,
            description: ev.description,
            category: ev.category,
            address: ev.full_address,
            status: ev.status,
            starts_at: ev.starts_at,
            ends_at: ev.ends_at,
            price: ev.display_price.to_f,
            currency: ev.currency,
            is_free: ev.free?,
            poster_url: ev.poster_image_url(host: base_url),
            has_poster: ev.has_poster?,
            photos: ev.photo_urls_array(host: base_url),
            photos_count: ev.photos_count,
            has_photos: ev.has_photos?,
            dress_code: ev.dress_code,
            age_restriction: ev.age_restriction,
            smoking: ev.smoking,
            id_required: ev.id_required,
            id_requirement_description: ev.id_requirement_description,
            restrictions: ev.restrictions,
            access_instructions: ev.access_instructions,
            cancellation_info: ev.cancellation_policy_info,
            cancellation_fee_percentage: ev.cancellation_fee_percentage&.to_f,
            categories: ev.all_categories,
            artist: ev.event_artists.includes(:artist).ordered.map { |ea|
              {
                id: ea.artist_id,
                name: ea.display_name,
                username: ea.artist&.username
              }
            },
            posted_by_name: ev.venue.owner&.name,
            rating_count: (ev.ratings.approved.count + ev.vibe_checks_count),
            user_has_rsvp: ev.user_has_rsvp?(current_user),
            age_price_enable: ev.age_pricing_enabled?,
            has_pre_booking: ev.has_pre_booking?,
            pre_booking_active: ev.pre_booking_active?,
            pre_booking_price: ev.pre_booking_price&.to_f,
            pre_booking_deadline: ev.pre_booking_deadline&.iso8601,
            venue: {
              id: ev.venue.id,
              name: ev.venue.name,
              address: ev.venue.full_address
            },
            # Always list tiers for ticket-mode events (even when this booking is RSVP-style with no ticket_lines).
            attendance_mode: ev.attendance_mode || 'rsvp',
            tickets_closed: ev.tickets_closed?,
            ticket_sales_open: ev.ticket_sales_open?,
            ticket_types: ev.event_ticket_types.sort_by { |t| [t.display_order, t.id] }.map { |t|
              detail = ticket_type_detail_payload(t, ev)
              detail.merge(ticket_type: detail.deep_dup)
            }
          }
        end

        if include_preorder
          preorders = booking.food_bar_orders
          response[:preorder] = {
            has_preorder: preorders.any?,
            items_count: preorders.sum { |o| o.food_bar_order_items.count },
            total_amount: preorders.sum(&:total_amount).to_f,
            orders: preorders.map do |order|
              {
                id: order.id,
                order_number: order.order_number,
                status: order.status,
                payment_status: order.payment_status,
                total_amount: order.total_amount.to_f,
                tip_amount: order.tip_amount.to_f,
                special_instructions: order.special_instructions,
                allergies: order.allergies,
                time_window_start: order.time_window_start&.iso8601,
                time_window_end: order.time_window_end&.iso8601,
                items: order.food_bar_order_items.map do |item|
                  {
                    menu_item_id: item.menu_item_id,
                    name: item.menu_item.name,
                    quantity: item.quantity,
                    price: item.total_price.to_f
                  }
                end
              }
            end
          }
        end
        
        response
      end

      # Returns (and creates if needed) the 1:1 booking-scoped chat id between the booking user
      # and the assigned PR user. Nil when booking is unassigned.
      def booking_assigned_pr_chat_id(booking)
        pr_user = booking.assigned_pr_user
        return nil unless pr_user

        # Only expose/create booking-scoped chats to participants or venue-side users.
        if booking.user_id != current_user.id && !can_access_event_pr_chat_users?(booking.event)
          return nil
        end

        user1_id, user2_id = [booking.user_id, pr_user.id].sort
        chat = Chat.find_by(user1_id: user1_id, user2_id: user2_id, booking_id: booking.id)
        return chat.id if chat

        Chat.create!(user1_id: user1_id, user2_id: user2_id, booking_id: booking.id).id
      rescue ActiveRecord::RecordInvalid
        # In case of a race, fall back to lookup.
        Chat.find_by(user1_id: user1_id, user2_id: user2_id, booking_id: booking.id)&.id
      end

      def can_view_booking?(booking)
        return false unless current_user && booking

        return false if booking.user_id == current_user.id && !booking.visible_in_listings?

        return true if booking.user_id == current_user.id
        return true if current_user.role_admin?
        return true if booking.event.creator_id == current_user.id
        return true if venue_manager_for_booking_event_venue?(booking)
        return true if active_pr_for_booking_event_venue?(booking)

        false
      end

      def can_adjust_booking_price?(booking)
        current_user.role_admin? ||
          booking.event.creator_id == current_user.id ||
          venue_manager_for_booking_event_venue?(booking) ||
          active_pr_for_booking_event_venue?(booking)
      end

      def venue_manager_for_booking_event_venue?(booking)
        venue_id = booking.event&.venue_id
        return false if venue_id.blank?

        return true if booking.event.venue&.owner_id == current_user.id

        VenueStaff.active.by_role('manager').exists?(venue_id: venue_id, user_id: current_user.id)
      end

      def active_pr_for_booking_event_venue?(booking)
        venue_id = booking.event&.venue_id
        return false if venue_id.blank?

        current_user.active_pr_partnerships.exists?(venue_id: venue_id)
      end

      def find_bookable_table_for_booking(event_or_booking, table_number)
        venue = event_or_booking.respond_to?(:venue) ? event_or_booking.venue : event_or_booking.event.venue
        active_plans = venue.floor_plans.active
        plans_scope = active_plans.exists? ? active_plans : venue.floor_plans

        Table.joins(floor_plan_zone: :floor_plan)
             .where(floor_plans: { id: plans_scope.select(:id) })
             .where(table_number: table_number)
             .where(is_active: true, is_bookable: true)
             .first
      end

      def apply_promo_to_price(price, currency, event, promo_code_param)
        return {
          final_price: price,
          original_price: nil,
          discount_amount: nil,
          promo_code_id: nil,
          promo_code: nil
        } if promo_code_param.blank?

        promo_code = PromoCode.find_by(code: promo_code_param.to_s.strip.upcase)
        return { error: 'Invalid promo code' } unless promo_code
        return { error: 'Promo code is not available' } unless promo_code.usable?(event: event, venue: event&.venue)

        if promo_code.discount_type == 'fixed' && promo_code.currency.present? && promo_code.currency != currency
          return { error: 'Promo code currency does not match booking currency' }
        end

        discount_amount = promo_code.apply_to(price)
        final_price = [price.to_f - discount_amount, 0.0].max.round(2)

        {
          final_price: final_price,
          original_price: price,
          discount_amount: discount_amount,
          promo_code_id: promo_code.id,
          promo_code: promo_code.code
        }
      end

      # True when client sent ticket_lines at root or under booking (same as parse_ticket_lines_param).
      def ticket_lines_in_request?
        raw = params[:ticket_lines].presence || params.dig(:booking, :ticket_lines)
        raw.is_a?(Array) && raw.any?
      end

      def extract_attendee_counts
        b = params[:booking]
        counts = {
          adults: params[:adults_count].presence || (b && (b[:adults_count] || b['adults_count'])),
          children: params[:children_count].presence || (b && (b[:children_count] || b['children_count'])),
          infants: params[:infants_count].presence || (b && (b[:infants_count] || b['infants_count'])),
          pets: params[:pets_count].presence || (b && (b[:pets_count] || b['pets_count']))
        }
        counts.transform_values! { |value| value.present? ? value.to_i : nil }

        if counts.values.compact.empty?
          counts[:adults] = 1
        end

        counts[:adults] ||= 0
        counts[:children] ||= 0
        counts[:infants] ||= 0
        counts[:pets] ||= 0

        counts
      end

      def valid_attendee_counts?(counts)
        counts.values.all? { |value| value.is_a?(Integer) && value >= 0 } &&
          counts.values.sum.positive?
      end

      def calculate_booking_price(event, counts)
        return 0.0 if event.free?

        if event.age_pricing_enabled?
          age_total = (counts[:adults] * (event.adult_price || 0)) +
            (counts[:children] * (event.child_price || 0)) +
            (counts[:infants] * (event.infant_price || 0)) +
            (counts[:pets] * (event.pet_price || 0))
          # If age prices are all zero but event has a flat price, use flat price
          age_total.positive? ? age_total : (event.price.to_f || 0.0)
        else
          event.display_price.to_f
        end
      end

      # Update ticket lines for a ticket booking and keep derived fields in sync.
      # Only safe while payment hasn't started (pending with paid_amount==0), enforced by caller.
      def update_ticket_lines_for_booking!(booking, ticket_lines)
        event = booking.event
        raise ArgumentError, 'Event not found' unless event

        new_qty_by_tt = ticket_lines.each_with_object({}) do |row, acc|
          tt_id = row[:event_ticket_type_id] || row['event_ticket_type_id']
          qty = row[:quantity] || row['quantity']
          key = tt_id.to_s
          raise ArgumentError, 'event_ticket_type_id is required' if key.blank?
          acc[key] = qty.to_i
        end

        old_qty_by_tt = booking.booking_ticket_lines.each_with_object({}) do |line, acc|
          key = line.event_ticket_type_id.to_s
          acc[key] = (acc[key] || 0) + line.quantity.to_i
        end

        all_tt_ids = (new_qty_by_tt.keys + old_qty_by_tt.keys).uniq
        types = event.event_ticket_types.lock.where(id: all_tt_ids).to_a

        if types.size != all_tt_ids.size
          missing = all_tt_ids - types.map { |t| t.id.to_s }
          raise ArgumentError, "Invalid ticket type(s): #{missing.join(', ')}"
        end

        # Adjust inventory based on quantity changes.
        types.each do |tt|
          key = tt.id.to_s
          old_qty = old_qty_by_tt[key].to_i
          new_qty = new_qty_by_tt[key].to_i
          delta = new_qty - old_qty
          next if delta.zero?
          delta.positive? ? tt.reserve!(delta) : tt.release!(-delta)
        end

        # Replace ticket lines to match requested quantities.
        booking.booking_ticket_lines.destroy_all
        total_price = 0.to_d
        types.each do |tt|
          qty = new_qty_by_tt[tt.id.to_s].to_i
          next if qty <= 0
          line_total = tt.price.to_d * qty
          booking.booking_ticket_lines.create!(
            event_ticket_type: tt,
            quantity: qty,
            unit_price: tt.price,
            line_total: line_total
          )
          total_price += line_total
        end

        # Rebuild entitlements to align with new ticket quantities.
        booking.ticket_entitlements.destroy_all
        position = 0
        entitlement_status = total_price.zero? ? 'active' : 'pending_payment'
        booking.booking_ticket_lines.includes(:event_ticket_type).find_each do |line|
          line.quantity.to_i.times do
            booking.ticket_entitlements.create!(
              event_ticket_type: line.event_ticket_type,
              purchaser: booking.user,
              holder: booking.user,
              status: entitlement_status,
              position: position
            )
            position += 1
          end
        end

        # Keep booking price + payment_status consistent with the new total.
        attrs = { price: total_price }
        if total_price.zero?
          attrs[:payment_status] = 'paid'
        else
          attrs[:payment_status] = 'pending'
        end
        booking.update!(attrs)
      end

      def validate_preorder_items(event, items_params)
        items_params.each do |item_param|
          menu_item_id = item_param[:menu_item_id] || item_param['menu_item_id']
          quantity = item_param[:quantity] || item_param['quantity'] || 1

          menu_item = resolve_menu_item_for_event(event, menu_item_id)
          return 'Menu item not found' unless menu_item
          return "#{menu_item.name} is currently unavailable" unless menu_item.is_available
          return 'Quantity must be greater than 0' unless quantity.to_i > 0

          menu = menu_item.menu_category&.event_menu
          return 'Menu item is not available for this event' unless menu&.event_id == event.id
          return 'Menu is not active for this event' unless menu.is_active
        end

        nil
      end

      def create_preorder(event, booking, preorder_params, time_window_start:, time_window_end:)
        items_params = preorder_params[:items] || preorder_params['items'] || []

        order = event.food_bar_orders.build(
          user: current_user,
          booking: booking,
          order_type: preorder_params[:order_type] || preorder_params['order_type'] || 'both',
          table_number: preorder_params[:table_number] || preorder_params['table_number'] || booking.table_number,
          special_instructions: preorder_params[:special_instructions] || preorder_params['special_instructions'],
          allergies: preorder_params[:allergies] || preorder_params['allergies'],
          dietary_restrictions: preorder_params[:dietary_restrictions] || preorder_params['dietary_restrictions'],
          tip_amount: preorder_params[:tip_amount]&.to_f || preorder_params['tip_amount']&.to_f || 0,
          tip_percentage: preorder_params[:tip_percentage]&.to_f || preorder_params['tip_percentage']&.to_f,
          currency: 'USD',
          time_window_start: time_window_start,
          time_window_end: time_window_end
        )

        subtotal = 0
        items_params.each do |item_param|
          menu_item_id = item_param[:menu_item_id] || item_param['menu_item_id']
          menu_item = resolve_menu_item_for_event(event, menu_item_id)
          unless menu_item
            @preorder_error = ['Menu item not found for this event']
            return nil
          end

          order_item = order.food_bar_order_items.build(
            menu_item: menu_item,
            quantity: item_param[:quantity] || item_param['quantity'] || 1,
            unit_price: menu_item.price,
            special_instructions: item_param[:special_instructions] || item_param['special_instructions'],
            customizations: (item_param[:customizations] || item_param['customizations'])&.to_json
          )

          item_total = order_item.total_price
          if item_total.nil?
            item_total = (order_item.unit_price || menu_item.price) * order_item.quantity
          end
          subtotal += item_total
        end

        order.subtotal = subtotal
        order.tax = (subtotal * 0.08).round(2)

        unless order.save
          @preorder_error = order.errors.full_messages.presence || ['Failed to create pre-order']
          return nil
        end

        order.update!(ordered_at: Time.current)
        order
      end

      def preorder_response(order)
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          payment_status: order.payment_status,
          order_type: order.order_type,
          total_amount: order.total_amount.to_f,
          currency: order.currency,
          time_window_start: order.time_window_start&.iso8601,
          time_window_end: order.time_window_end&.iso8601,
          items: order.food_bar_order_items.map do |item|
            {
              menu_item_id: item.menu_item_id,
              name: item.menu_item.name,
              quantity: item.quantity,
              price: item.total_price.to_f
            }
          end,
          ordered_at: order.ordered_at&.iso8601
        }
      end

      def resolve_menu_item_for_event(event, menu_item_id)
        return nil if menu_item_id.blank?

        menu_item = MenuItem.joins(menu_category: :event_menu)
                            .where(event_menus: { event_id: event.id })
                            .find_by(id: menu_item_id)
        return menu_item if menu_item

        venue_item = VenueMenuItem.find_by(id: menu_item_id)
        return nil unless venue_item

        return nil unless ensure_event_menus_from_venue!(event)

        find_event_menu_item_from_venue_item(event, venue_item)
      end

      def ensure_event_menus_from_venue!(event)
        return true if event.has_active_menus?

        venue_menus = event.venue.venue_menus.active.includes(venue_menu_categories: :venue_menu_items)
        return false if venue_menus.blank?

        EventMenu.transaction do
          venue_menus.each do |venue_menu|
            event_menu = event.event_menus.create!(
              name: venue_menu.name,
              menu_type: venue_menu.menu_type,
              description: venue_menu.description,
              is_active: venue_menu.is_active,
              available_from: venue_menu.available_from,
              available_until: venue_menu.available_until
            )

            venue_menu.venue_menu_categories.each do |venue_category|
              next unless venue_category.is_active

              category_type = venue_category.category_type
              category_type = 'other' unless MenuCategory::CATEGORY_TYPES.include?(category_type)

              event_category = event_menu.menu_categories.create!(
                name: venue_category.name,
                description: venue_category.description,
                category_type: category_type,
                display_order: venue_category.display_order,
                is_active: venue_category.is_active
              )

              venue_category.venue_menu_items.each do |venue_item|
                event_category.menu_items.create!(
                  name: venue_item.name,
                  description: venue_item.description,
                  price: venue_item.price,
                  currency: venue_item.currency,
                  item_type: venue_item.item_type,
                  image_url: venue_item.image_url,
                  is_available: venue_item.is_available,
                  is_vegetarian: venue_item.is_vegetarian,
                  is_vegan: venue_item.is_vegan,
                  is_gluten_free: venue_item.is_gluten_free,
                  contains_alcohol: venue_item.contains_alcohol,
                  allergens: venue_item.allergens.to_json,
                  preparation_time_minutes: venue_item.preparation_time_minutes,
                  display_order: venue_item.display_order
                )
              end
            end
          end
        end

        event.reload
        event.has_active_menus?
      rescue => e
        Rails.logger.error "Failed to sync venue menus for event #{event.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        false
      end

      def fetch_modifiable_preorder
        order = @booking.food_bar_orders.order(created_at: :desc).first
        unless order
          api_error(message: 'Pre-order not found for this booking', status: :not_found)
          return nil
        end

        unless order.status_pending? && order.payment_pending?
          api_error(message: 'Pre-order cannot be modified at this stage', status: :unprocessable_entity)
          return nil
        end

        order
      end

      # Returns a modifiable preorder without setting errors (for use when we want to create new if none exists)
      def find_modifiable_preorder
        order = @booking.food_bar_orders.order(created_at: :desc).first
        return nil unless order
        return nil unless order.status_pending? && order.payment_pending?
        order
      end

      def recalc_preorder_totals!(order)
        subtotal = 0
        order.food_bar_order_items.each do |order_item|
          item_total = order_item.total_price
          if item_total.nil?
            item_total = (order_item.unit_price || order_item.menu_item.price) * order_item.quantity
          end
          subtotal += item_total
        end
        order.update!(subtotal: subtotal, tax: (subtotal * 0.08).round(2))
      end

      def find_event_menu_item_from_venue_item(event, venue_item)
        venue_category = venue_item.venue_menu_category
        venue_menu = venue_category.venue_menu

        MenuItem.joins(menu_category: :event_menu)
                .where(
                  event_menus: { event_id: event.id, name: venue_menu.name },
                  menu_categories: { name: venue_category.name },
                  menu_items: { name: venue_item.name, price: venue_item.price }
                )
                .first
      end

      def parse_time_param(raw_value)
        return nil if raw_value.blank?
        return raw_value if raw_value.is_a?(Time) || raw_value.is_a?(ActiveSupport::TimeWithZone)

        parsed = Time.zone.parse(raw_value.to_s)
        parsed || :invalid
      end
    end
  end
end

