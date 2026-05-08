module Api
  module V1
    class VenueManagerController < ApplicationController
      before_action :require_authentication!
      before_action :require_venue_manager!
      before_action :set_venue, except: [:my_venues, :dashboard_summary]
      before_action :set_event, only: [:event_participants, :pending_cancellations, :approve_cancellation, :reject_cancellation, :event_rsvps, :approve_rsvp, :block_rsvp, :cancel_rsvp]
      before_action :set_booking, only: [:booking_details, :approve_booking, :reject_booking, :block_booking, :cancel_booking_by_manager, :assign_booking_pr, :unassign_booking_pr]
      
      # GET /api/v1/venue_manager/my_venues
      def my_venues
        venues = current_user.venues.includes(:events)
        
        api_success(
          data: {
            venues: venues.map { |venue| venue_summary(venue) }
          }
        )
      end
      
      # GET /api/v1/venue_manager/dashboard_summary
      def dashboard_summary
        venues = current_user.venues
        
        # Aggregate stats across all venues
        total_events = Event.where(venue: venues).count
        upcoming_events = Event.where(venue: venues).upcoming.count
        active_bookings = Booking.joins(:event).where(events: { venue: venues }).confirmed.upcoming.count
        
        api_success(
          data: {
            total_venues: venues.count,
            total_events: total_events,
            upcoming_events: upcoming_events,
            active_bookings: active_bookings,
            venues: venues.map { |venue| venue_summary(venue) }
          }
        )
      end
      
      # GET /api/v1/venues/:venue_id/dashboard
      def dashboard
        # Today's stats
        today = Time.current.beginning_of_day..Time.current.end_of_day
        
        todays_events = @venue.events.where(starts_at: today)
        todays_bookings = Booking.joins(:event).where(events: { venue_id: @venue.id, starts_at: today })
        todays_orders = FoodBarOrder.where(event: @venue.events, created_at: today)
        
        # Pending items requiring attention
        pending_waiter_calls = WaiterCall.joins(:event)
                                         .where(events: { venue_id: @venue.id })
                                         .pending
                                         .count
        
        pending_orders = FoodBarOrder.where(event: @venue.events)
                                     .where(status: ['pending', 'confirmed'])
                                     .count
        
        # Revenue stats (last 30 days)
        revenue_30d = calculate_revenue(@venue, 30.days.ago)
        
        api_success(
          data: {
            venue: {
              id: @venue.id,
              name: @venue.name,
              city: @venue.city
            },
            today: {
              events_count: todays_events.count,
              bookings_count: todays_bookings.count,
              orders_count: todays_orders.count,
              revenue: todays_orders.where(payment_status: 'paid').sum(:total_amount).to_f
            },
            pending_attention: {
              waiter_calls: pending_waiter_calls,
              pending_orders: pending_orders
            },
            revenue_30_days: revenue_30d,
            upcoming_events: @venue.events.upcoming.limit(5).map { |e| event_summary(e) }
          }
        )
      end
      
      # GET /api/v1/venues/:venue_id/manager/dashboard_metrics
      # Query: period=weekly|monthly|6months|1year
      # Returns RSVP and Tickets metrics for the selected period
      def dashboard_metrics
        since = period_to_since(params[:period])

        # RSVP: Free bookings (no payment) + event interests (attending)
        free_bookings = Booking.joins(:event)
                              .where(events: { venue_id: @venue.id })
                              .where('bookings.created_at >= ?', since)
                              .where('bookings.price = 0')
                              .where(status: %w[created confirmed checked_in])
        rsvp_interests = EventInterest.joins(:event)
                                      .where(events: { venue_id: @venue.id })
                                      .where('event_interests.responded_at >= ?', since)
                                      .attending
        rsvp_total = free_bookings.count + rsvp_interests.count
        rsvp_earned = 0.0

        # Tickets: Paid bookings (bookings.price to avoid ambiguous column with events.price)
        paid_bookings = Booking.joins(:event)
                              .where(events: { venue_id: @venue.id })
                              .where('bookings.created_at >= ?', since)
                              .where('bookings.price > 0')
                              .where(status: %w[created confirmed checked_in])
        tickets_sold = paid_bookings.count
        tickets_earned = paid_bookings.paid.sum(:paid_amount).to_f

        refunded = Booking.joins(:event)
                         .where(events: { venue_id: @venue.id })
                         .where('bookings.created_at >= ?', since)
                         .where(payment_status: 'refunded')
                         .sum(:paid_amount)
                         .to_f
        net = tickets_earned - refunded

        api_success(
          data: {
            period: params[:period] || 'monthly',
            period_start: since.iso8601,
            rsvp: {
              total_rsvp_bookings: rsvp_total,
              total_earned: rsvp_earned
            },
            tickets: {
              total_tickets_sold: tickets_sold,
              total_earned: tickets_earned,
              refunded: refunded,
              net: net
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/venues/:venue_id/analytics
      def analytics
        period = params[:period] || '30' # days
        start_date = period.to_i.days.ago
        
        events = @venue.events.where('created_at >= ?', start_date)
        bookings = Booking.joins(:event).where(events: { venue_id: @venue.id }).where('bookings.created_at >= ?', start_date)
        orders = FoodBarOrder.where(event: @venue.events).where('created_at >= ?', start_date)
        
        api_success(
          data: {
            period_days: period.to_i,
            events: {
              total: events.count,
              published: events.published.count,
              draft: events.draft.count,
              canceled: events.where(status: 'canceled').count
            },
            bookings: {
              total: bookings.count,
              confirmed: bookings.confirmed.count,
              checked_in: bookings.checked_in.count,
              revenue: bookings.paid.sum(:price).to_f
            },
            orders: {
              total: orders.count,
              completed: orders.where(status: 'completed').count,
              revenue: orders.where(payment_status: 'paid').sum(:total_amount).to_f,
              average_order_value: orders.where(payment_status: 'paid').average(:total_amount).to_f
            },
            top_menu_items: top_menu_items(@venue, start_date, 10)
          }
        )
      end
      
      # GET /api/v1/venues/:venue_id/staff
      def staff_list
        staff = @venue.venue_staff.includes(:user).order(created_at: :desc)
        
        api_success(
          data: {
            staff: staff.map { |s| staff_response(s) }
          }
        )
      end
      
      # POST /api/v1/venues/:venue_id/staff
      def add_staff
        user = User.find_by(email: params[:email]) || User.find_by(phone: params[:phone])
        
        unless user
          api_error(message: 'User not found', status: :not_found)
          return
        end
        
        staff = @venue.venue_staff.build(
          user: user,
          role: params[:role] || 'waiter',
          status: 'active',
          receives_notifications: true
        )
        
        if staff.save
          api_success(
            data: { staff: staff_response(staff) },
            message: 'Staff member added successfully',
            status: :created
          )
        else
          api_validation_error(errors: staff.errors.full_messages)
        end
      end
      
      # PATCH /api/v1/venues/:venue_id/staff/:id
      def update_staff
        staff = @venue.venue_staff.find(params[:id])
        
        if staff.update(staff_params)
          api_success(
            data: { staff: staff_response(staff) },
            message: 'Staff updated successfully'
          )
        else
          api_validation_error(errors: staff.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/venues/:venue_id/staff/:id
      def remove_staff
        staff = @venue.venue_staff.find(params[:id])
        staff.destroy
        
        api_success(message: 'Staff member removed successfully')
      end
      
      # POST /api/v1/venues/:venue_id/staff/:id/update_location
      def update_staff_location
        staff = @venue.venue_staff.find(params[:id])
        
        unless staff.user_id == current_user.id
          api_error(message: 'You can only update your own location', status: :forbidden)
          return
        end
        
        staff.update_location(params[:latitude], params[:longitude])
        
        api_success(
          data: { 
            staff: staff_response(staff),
            location_updated_at: staff.last_location_update
          },
          message: 'Location updated successfully'
        )
      end
      
      # GET /api/v1/venues/:venue_id/tables_overview
      def tables_overview
        event_id = params[:event_id]
        table_index = tables_for_venue_overview.index_by(&:table_number)
        bookings_query = Booking.joins(:event)
                                .where(events: { venue_id: @venue.id })
                                .where(status: ['confirmed', 'checked_in'])
                                .where.not(table_number: nil)
                                .includes(
                                  :user,
                                  :event,
                                  :vibe_check,
                                  :payment_transaction,
                                  :food_bar_orders => { :food_bar_order_items => :menu_item }
                                )
        bookings_query = bookings_query.where(event_id: event_id) if event_id.present?
        bookings_by_table = bookings_query.index_by(&:table_number)
        
        # Get all orders for the venue (or specific event)
        orders_query = FoodBarOrder.joins(:event)
                                   .where(events: { venue_id: @venue.id })
                                   .where.not(table_number: nil)
                                   .where(status: ['pending', 'confirmed', 'preparing', 'ready', 'delivered', 'completed'])
                                   .includes(:user, :food_bar_order_items, :bill_splits)
        
        orders_query = orders_query.where(event_id: event_id) if event_id.present?
        
        # Group by table number
        tables = build_tables_from_orders(orders_query, table_index)
        table_index.each do |table_number, table|
          tables[table_number] ||= default_table_entry(table_number: table_number, table: table)
        end
        bookings_by_table.each do |table_number, booking|
          tables[table_number] ||= default_table_entry(table_number: table_number, table: table_index[table_number])
          tables[table_number][:booking] ||= detailed_booking_response(booking)
        end
        apply_table_statuses!(tables)
        
        # Sort by table number
        sorted_tables = tables.values.sort_by { |t| t[:table_number] }
        
        api_success(
          data: {
            tables: sorted_tables,
            summary: {
              total_tables: sorted_tables.count,
              available: sorted_tables.count { |t| t[:status] == 'available' },
              occupied: sorted_tables.count { |t| t[:status] == 'occupied' },
              in_service: sorted_tables.count { |t| t[:status] == 'in_service' },
              waiting_payment: sorted_tables.count { |t| t[:status] == 'waiting_payment' },
              total_revenue: sorted_tables.sum { |t| t[:paid_amount] },
              pending_revenue: sorted_tables.sum { |t| t[:unpaid_amount] }
            }
          }
        )
      end

      # GET /api/v1/venues/:venue_id/manager/orders
      # List tables grouped by paid/in-progress/unpaid for orders tab
      def orders_tables
        event_id = params[:event_id]

        orders_query = FoodBarOrder.joins(:event)
                                   .where(events: { venue_id: @venue.id })
                                   .where.not(table_number: nil)
                                   .where(status: ['pending', 'confirmed', 'preparing', 'ready', 'delivered', 'completed'])
                                   .includes(:user, :food_bar_order_items, :bill_splits)
        
        orders_query = orders_query.where(event_id: event_id) if event_id.present?

        tables = build_tables_from_orders(orders_query)
        apply_table_statuses!(tables)

        grouped_tables = {
          paid: [],
          in_progress: [],
          unpaid: []
        }

        tables.values.each do |table_data|
          if table_data[:has_unpaid_orders]
            grouped_tables[:unpaid] << table_data
          elsif table_data[:has_pending_orders]
            grouped_tables[:in_progress] << table_data
          else
            grouped_tables[:paid] << table_data
          end
        end

        grouped_tables.each_value do |group|
          group.sort_by! { |t| t[:table_number] }
        end

        api_success(
          data: {
            tables: grouped_tables,
            summary: {
              total_tables: tables.values.count,
              paid_tables: grouped_tables[:paid].count,
              in_progress_tables: grouped_tables[:in_progress].count,
              unpaid_tables: grouped_tables[:unpaid].count
            }
          }
        )
      end

      # GET /api/v1/venues/:venue_id/manager/preorders
      # List tables that are booked (pre-orders tab)
      def preorders_tables
        event_id = params[:event_id]
        table_index = tables_for_venue_overview.index_by(&:table_number)

        bookings_query = Booking.joins(:event)
                                .where(events: { venue_id: @venue.id })
                                .where(status: ['confirmed', 'checked_in'])
                                .where.not(table_number: nil)
                                .includes(
                                  :user,
                                  :event,
                                  :vibe_check,
                                  :payment_transaction,
                                  :food_bar_orders => { :food_bar_order_items => :menu_item }
                                )

        bookings_query = bookings_query.where(event_id: event_id) if event_id.present?

        tables = bookings_query.group_by(&:table_number).map do |table_number, bookings|
          table = table_index[table_number]
          bookings_data = bookings.map do |booking|
            booking_data = detailed_booking_response(booking)
            booking_data[:table] = table_summary(table_index[booking.table_number])
            booking_data
          end
          items_count = bookings_data.sum do |booking_data|
            booking_data.dig(:preorder, :items_count).to_i
          end
          {
            table_number: table_number,
            status: bookings.any?(&:status_checked_in?) ? 'checked_in' : 'booked',
            table: table_summary(table),
            items_count: items_count,
            bookings: bookings_data
          }
        end

        sorted_tables = tables.sort_by { |table| table[:table_number] }

        api_success(
          data: {
            tables: sorted_tables,
            summary: {
              total_tables: sorted_tables.count,
              total_bookings: bookings_query.count,
              checked_in_tables: sorted_tables.count { |table| table[:status] == 'checked_in' }
            }
          }
        )
      end

      # GET /api/v1/venues/:venue_id/manager/waiting_waiter
      # List in-progress waiter tables and show details
      def waiting_waiter_tables
        event_id = params[:event_id]
        status_filter = params[:status].presence

        calls_query = WaiterCall.joins(:event)
                                .where(events: { venue_id: @venue.id })
                                .where.not(table_number: nil)
                                .includes(:user, :order, :assigned_staff)

        calls_query = calls_query.where(event_id: event_id) if event_id.present?
        if status_filter.present?
          calls_query = calls_query.where(status: status_filter)
        else
          calls_query = calls_query.active
        end

        calls = calls_query.order(created_at: :asc)

        tables = {}
        calls.each do |call|
          table_number = call.table_number
          tables[table_number] ||= {
            table_number: table_number,
            calls: [],
            orders: [],
            booking: nil,
            items_count: 0
          }
          tables[table_number][:calls] << call_summary(call)
        end

        if tables.any?
          orders = FoodBarOrder.joins(:event)
                               .where(events: { venue_id: @venue.id })
                               .where(table_number: tables.keys)
                               .includes(:user, :food_bar_order_items => :menu_item, :bill_splits => :user)

          orders = orders.where(event_id: event_id) if event_id.present?

          orders.each do |order|
            table_data = tables[order.table_number]
            next unless table_data
            order_data = table_order_response(order)
            table_data[:orders] << order_data
            table_data[:items_count] += order_data[:items_count].to_i
          end

          bookings = Booking.joins(:event)
                            .where(events: { venue_id: @venue.id })
                            .where(table_number: tables.keys)
                            .where(status: ['confirmed', 'checked_in'])
                            .includes(:user, :event)

          bookings = bookings.where(event_id: event_id) if event_id.present?

          bookings.each do |booking|
            table_data = tables[booking.table_number]
            next unless table_data
            table_data[:booking] ||= booking_table_response(booking)
          end
        end

        sorted_tables = tables.values.sort_by { |table| table[:table_number] }
        
        api_success(
          data: {
            tables: sorted_tables,
            summary: {
              total_tables: sorted_tables.count,
              total_calls: calls.count,
              status_filter: status_filter || 'active'
            }
          }
        )
      end
      
      # GET /api/v1/venues/:venue_id/table/:table_number
      def table_details
        table_number = params[:table_number]
        
        # Get all orders for this table
        orders = FoodBarOrder.joins(:event)
                             .where(events: { venue_id: @venue.id })
                             .where(table_number: table_number)
                             .includes(:user, :food_bar_order_items => :menu_item, :bill_splits => :user)
                             .order(created_at: :desc)
        
        # Current booking at table (if any)
        current_booking = Booking.joins(:event)
                                 .where(events: { venue_id: @venue.id })
                                 .where(table_number: table_number)
                                 .where(status: ['confirmed', 'checked_in'])
                                 .first
        
        # Calculate totals
        total_amount = orders.sum(:total_amount)
        paid_amount = orders.where(payment_status: 'paid').sum(:total_amount)
        unpaid_amount = total_amount - paid_amount
        
        api_success(
          data: {
            table_number: table_number,
            booking: current_booking ? {
              id: current_booking.id,
              user: {
                id: current_booking.user.id,
                name: current_booking.user.name
              },
              checked_in_at: current_booking.checked_in_at&.iso8601
            } : nil,
            orders: orders.map { |order| table_order_response(order) },
            summary: {
              total_orders: orders.count,
              active_orders: orders.where(status: ['pending', 'confirmed', 'preparing', 'ready']).count,
              total_amount: total_amount.to_f,
              paid_amount: paid_amount.to_f,
              unpaid_amount: unpaid_amount.to_f,
              payment_status: unpaid_amount > 0 ? 'unpaid' : 'paid'
            }
          }
        )
      end
      
      # POST /api/v1/venues/:venue_id/tables/:table_number/assign_booking
      def assign_table
        booking = Booking.find(params[:booking_id])
        table_number = params[:table_number].to_s.strip

        unless booking.event.venue_id == @venue.id
          api_error(message: 'Booking not for this venue', status: :bad_request)
          return
        end

        if Booking.table_occupied_for_event?(booking.event_id, table_number, exclude_booking_id: booking.id)
          api_error(message: 'This table is already booked for this event', status: :unprocessable_entity)
          return
        end

        booking.update!(
          table_number: table_number,
          assigned_by_id: current_user.id,
          table_assigned_at: Time.current
        )
        BookingBroadcaster.table_assigned(booking, table_number: table_number)
        
        api_success(
          data: { 
            booking: {
              id: booking.id,
              table_number: booking.table_number,
              user: { name: booking.user.name }
            }
          },
          message: "Table #{table_number} assigned successfully"
        )
      end
      
      # GET /api/v1/venues/:venue_id/live_orders
      def live_orders
        # Active orders that need attention
        orders = FoodBarOrder.joins(:event)
                             .where(events: { venue_id: @venue.id })
                             .where(status: ['pending', 'confirmed', 'preparing', 'ready'])
                             .includes(:user, :food_bar_order_items => :menu_item)
                             .order(created_at: :asc)
        
        # Group by status for kitchen/bar display
        grouped_orders = {
          pending: orders.status_pending.map { |o| order_summary(o) },
          confirmed: orders.status_confirmed.map { |o| order_summary(o) },
          preparing: orders.status_preparing.map { |o| order_summary(o) },
          ready: orders.status_ready.map { |o| order_summary(o) }
        }
        
        api_success(
          data: {
            orders: grouped_orders,
            stats: {
              total_active: orders.count,
              pending_count: orders.status_pending.count,
              preparing_count: orders.status_preparing.count,
              ready_count: orders.status_ready.count
            }
          }
        )
      end
      
      # POST /api/v1/venues/:venue_id/orders/:order_id/update_status
      def update_order_status
        order = FoodBarOrder.joins(:event)
                            .where(events: { venue_id: @venue.id })
                            .find(params[:order_id])
        
        new_status = params[:status]
        
        case new_status
        when 'confirmed'
          order.confirm!
        when 'preparing'
          order.mark_preparing!
        when 'ready'
          order.mark_ready!
        when 'delivered'
          order.mark_delivered!
        when 'completed'
          order.complete!
        else
          api_error(message: 'Invalid status', status: :bad_request)
          return
        end
        
        api_success(
          data: { order: order_summary(order) },
          message: "Order status updated to #{new_status}"
        )
      end
      
      # GET /api/v1/venues/:venue_id/active_calls
      def active_calls
        calls = WaiterCall.joins(:event)
                          .where(events: { venue_id: @venue.id })
                          .active
                          .includes(:user)
                          .order(created_at: :asc)
        
        api_success(
          data: {
            calls: calls.map { |call| call_summary(call) },
            stats: {
              total_active: calls.count,
              pending: calls.pending.count,
              in_progress: calls.status_in_progress.count,
              emergency: calls.call_type_emergency.count
            }
          }
        )
      end
      
      # GET /api/v1/venues/:venue_id/revenue_report
      def revenue_report
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
        end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today
        
        bookings = Booking.joins(:event)
                          .where(events: { venue_id: @venue.id })
                          .where(created_at: start_date..end_date)
                          .paid
        
        orders = FoodBarOrder.joins(:event)
                             .where(events: { venue_id: @venue.id })
                             .where(created_at: start_date..end_date)
                             .where(payment_status: 'paid')
        
        api_success(
          data: {
            period: {
              start_date: start_date.iso8601,
              end_date: end_date.iso8601,
              days: (end_date - start_date).to_i + 1
            },
            revenue: {
              bookings: bookings.sum(:price).to_f,
              food_bar: orders.sum(:total_amount).to_f,
              total: bookings.sum(:price).to_f + orders.sum(:total_amount).to_f
            },
            bookings: {
              count: bookings.count,
              revenue: bookings.sum(:price).to_f,
              average_value: bookings.average(:price).to_f
            },
            orders: {
              count: orders.count,
              revenue: orders.sum(:total_amount).to_f,
              average_value: orders.average(:total_amount).to_f,
              total_tips: orders.sum(:tip_amount).to_f
            }
          }
        )
      end

       # GET /api/v1/venues/:venue_id/events/:event_id/participants
       def event_participants
        bookings = @event.bookings
                         .includes(:user, :vibe_check)
                         .order(created_at: :desc)
        
        # Filter by status
        bookings = bookings.where(status: params[:status]) if params[:status].present?
        
        api_success(
          data: {
            event: {
              id: @event.id,
              title: @event.title,
              starts_at: @event.starts_at,
              status: @event.status
            },
            participants: bookings.map { |booking| participant_response(booking) },
            stats: {
              total: @event.bookings.count,
              confirmed: @event.bookings.confirmed.count,
              checked_in: @event.bookings.checked_in.count,
              canceled: @event.bookings.canceled.count,
              pending_cancellations: @event.bookings.where(cancellation_requested: true, cancellation_approved: nil).count
            }
          }
        )
      end
      
      # GET /api/v1/venues/:venue_id/events/:event_id/pending_cancellations
      def pending_cancellations
        pending = @event.bookings
                        .where(cancellation_requested: true, cancellation_approved: nil)
                        .includes(:user)
                        .order(cancellation_requested_at: :asc)
        
        api_success(
          data: {
            pending_cancellations: pending.map { |booking| cancellation_request_response(booking) }
          }
        )
      end
      
      # POST /api/v1/venues/:venue_id/bookings/:booking_id/approve_cancellation
      def approve_cancellation
        booking = @event.bookings.find(params[:booking_id])
        
        unless booking.pending_cancellation?
          api_error(message: 'No pending cancellation request', status: :bad_request)
          return
        end
        
        booking.approve_cancellation!(approved_by: current_user)
        
        api_success(
          data: { booking: participant_response(booking) },
          message: 'Cancellation approved and refund processed'
        )
      end
      
      # POST /api/v1/venues/:venue_id/bookings/:booking_id/reject_cancellation
      def reject_cancellation
        booking = @event.bookings.find(params[:booking_id])
        
        unless booking.pending_cancellation?
          api_error(message: 'No pending cancellation request', status: :bad_request)
          return
        end
        
        reason = params[:rejection_reason] || 'Cancellation denied'
        
        booking.reject_cancellation!(
          rejected_reason: reason,
          approved_by: current_user
        )
        
        api_success(
          data: { booking: participant_response(booking) },
          message: 'Cancellation request rejected'
        )
      end
      
      # POST /api/v1/venues/:venue_id/blocklist/:user_id
      def add_to_blocklist
        user = User.find(params[:user_id])
        
        blocklist = @venue.venue_blocklists.build(
          user: user,
          blocked_by: current_user,
          reason: params[:reason],
          description: params[:description],
          incident_type: params[:incident_type],
          related_event_id: params[:related_event_id],
          related_booking_id: params[:related_booking_id],
          is_permanent: params[:is_permanent] || false,
          blocked_until: params[:blocked_until]
        )
        
        if blocklist.save
          api_success(
            data: { blocklist: blocklist_response(blocklist) },
            message: 'User added to blocklist',
            status: :created
          )
        else
          api_validation_error(errors: blocklist.errors.full_messages)
        end
      end
      
      # GET /api/v1/venues/:venue_id/blocklist
      def blocklist
        blocklists = @venue.venue_blocklists
                           .includes(:user, :blocked_by)
                           .order(created_at: :desc)
        
        # Filter active/expired
        case params[:filter]
        when 'active'
          blocklists = blocklists.active
        when 'expired'
          blocklists = blocklists.expired
        when 'permanent'
          blocklists = blocklists.permanent
        end
        
        api_success(
          data: {
            blocklists: blocklists.map { |bl| blocklist_response(bl) },
            stats: {
              total: @venue.venue_blocklists.count,
              active: @venue.venue_blocklists.active.count,
              permanent: @venue.venue_blocklists.permanent.count
            }
          }
        )
      end
      
      # DELETE /api/v1/venues/:venue_id/blocklist/:id
      def remove_from_blocklist
        blocklist = @venue.venue_blocklists.find(params[:id])
        blocklist.destroy
        
        api_success(message: 'User removed from blocklist')
      end
      
      # GET /api/v1/venues/:venue_id/bookings
      # List all bookings for all events at this venue
      def venue_bookings
        bookings = Booking.joins(:event)
                         .where(events: { venue_id: @venue.id })
                         .merge(Booking.visible_in_listings)
                         .includes(
                           :user,
                           :event,
                           :vibe_check,
                           :food_bar_orders,
                           :payment_transaction,
                           :assigned_pr_user,
                           :assigned_pr_assigned_by
                         )
                         .order(created_at: :desc)
        
        # Filter by status
        bookings = bookings.where(status: params[:status]) if params[:status].present?
        
        # Filter by payment_status
        bookings = bookings.where(payment_status: params[:payment_status]) if params[:payment_status].present?
        
        # Filter by event_id
        bookings = bookings.where(event_id: params[:event_id]) if params[:event_id].present?
        
        # Filter by search term (user name, email, booking ID)
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          bookings = bookings.joins(:user).where(
            "users.name ILIKE ? OR users.email ILIKE ? OR bookings.id::text ILIKE ?",
            search_term, search_term, search_term
          )
        end
        
        # Pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = bookings.count
        bookings = bookings.limit(limit).offset(offset)
        
        api_success(
          data: {
            bookings: bookings.map { |booking| detailed_booking_response(booking) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            },
            stats: {
              total: Booking.joins(:event).where(events: { venue_id: @venue.id }).count,
              confirmed: Booking.joins(:event).where(events: { venue_id: @venue.id }).confirmed.count,
              canceled: Booking.joins(:event).where(events: { venue_id: @venue.id }).canceled.count,
              checked_in: Booking.joins(:event).where(events: { venue_id: @venue.id }).checked_in.count,
              pending_payment: Booking.joins(:event).where(events: { venue_id: @venue.id }).pending_payment.count,
              paid: Booking.joins(:event).where(events: { venue_id: @venue.id }).paid.count
            }
          },
          status: :ok
        )
      end
      
      # GET /api/v1/venues/:venue_id/bookings/:booking_id
      # Get detailed booking information
      def booking_details
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end
        
        api_success(
          data: {
            booking: detailed_booking_response(@booking, include_full_details: true)
          },
          status: :ok
        )
      end
      
      # POST /api/v1/venues/:venue_id/bookings/:booking_id/approve
      # Approve a booking (confirm it)
      def approve_booking
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end
        
        if @booking.status_confirmed?
          api_error(message: 'Booking is already confirmed', status: :bad_request)
          return
        end
        
        if @booking.status_canceled?
          api_error(message: 'Cannot approve a canceled booking', status: :bad_request)
          return
        end
        
        @booking.update!(status: 'confirmed', expiry_at: nil)

        # Notify user that their booking was approved
        notify_user_booking_confirmed(@booking)
        BookingBroadcaster.venue_approved(@booking.reload)

        api_success(
          data: {
            booking: detailed_booking_response(@booking)
          },
          message: 'Booking approved successfully',
          status: :ok
        )
      end

      # POST /api/v1/venues/:venue_id/bookings/:booking_id/reject
      # Reject a booking request (RSVP reject - cancels without blocking user)
      def reject_booking
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end

        if @booking.status_canceled?
          api_error(message: 'Booking is already canceled', status: :bad_request)
          return
        end

        reason = params[:reason] || params[:rejection_reason] || 'Booking request rejected by venue'
        @booking.cancel!
        @booking.update!(cancellation_reason: reason)

        # Notify user that their booking was rejected
        notify_user_booking_rejected(@booking, reason)

        api_success(
          data: {
            booking: detailed_booking_response(@booking)
          },
          message: 'Booking rejected successfully',
          status: :ok
        )
      end

      # POST /api/v1/venues/:venue_id/manager/bookings/:booking_id/assign_pr
      # Assign a booking to an active PR user for this venue.
      # Body: pr_user_id (required)
      def assign_booking_pr
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end

        pr_user_id = params[:pr_user_id] || params[:user_id] || params.dig(:pr, :user_id) || current_user.id

        # If the caller is a PR for this venue, allow defaulting assignment to self.
        if pr_user_id.blank?
          api_error(message: 'pr_user_id is required', status: :bad_request)
          return
        end

        partnership = VenuePrPartnership.active.find_by(venue_id: @venue.id, user_id: pr_user_id)
        staff_manager = VenueStaff.active.by_role('manager').find_by(venue_id: @venue.id, user_id: pr_user_id)

        assignee_user =
          if partnership
            partnership.user
          elsif staff_manager
            staff_manager.user
          elsif pr_user_id == current_user.id
            current_user
          end

        unless assignee_user
          api_error(message: 'User is not an active PR or venue manager for this venue', status: :unprocessable_entity)
          return
        end

        @booking.update!(
          assigned_pr_user: assignee_user,
          assigned_pr_assigned_by: current_user,
          assigned_pr_assigned_at: Time.current
        )

        # Realtime update for booking owner + venue-side subscribers
        BookingBroadcaster.status_updated(@booking.reload)

        api_success(
          data: { booking: detailed_booking_response(@booking) },
          message: 'Booking assigned to PR successfully',
          status: :ok
        )
      end

      # POST /api/v1/venues/:venue_id/manager/bookings/:booking_id/unassign_pr
      def unassign_booking_pr
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end

        @booking.update!(
          assigned_pr_user: nil,
          assigned_pr_assigned_by: current_user,
          assigned_pr_assigned_at: Time.current
        )

        # Realtime update for booking owner + venue-side subscribers
        BookingBroadcaster.status_updated(@booking.reload)

        api_success(
          data: { booking: detailed_booking_response(@booking) },
          message: 'Booking unassigned from PR successfully',
          status: :ok
        )
      end
      
      # POST /api/v1/venues/:venue_id/bookings/:booking_id/block
      # Block a booking and add user to blocklist
      def block_booking
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end
        
        reason = params[:reason] || 'Booking blocked by venue manager'
        incident_type = params[:incident_type] || 'other'
        
        # Add user to blocklist
        blocklist = @venue.venue_blocklists.build(
          user: @booking.user,
          blocked_by: current_user,
          reason: reason,
          description: params[:description],
          incident_type: incident_type,
          related_event_id: @booking.event_id,
          related_booking_id: @booking.id,
          is_permanent: params[:is_permanent] || false,
          blocked_until: params[:blocked_until]
        )
        
        if blocklist.save
          # Cancel the booking
          @booking.cancel! if @booking.status_confirmed?
          
          api_success(
            data: {
              booking: detailed_booking_response(@booking),
              blocklist: blocklist_response(blocklist)
            },
            message: 'Booking blocked and user added to blocklist',
            status: :ok
          )
        else
          api_validation_error(errors: blocklist.errors.full_messages)
        end
      end
      
      # POST /api/v1/venues/:venue_id/bookings/:booking_id/cancel
      # Cancel a booking (venue manager initiated)
      def cancel_booking_by_manager
        unless @booking.event.venue_id == @venue.id
          api_error(message: 'Booking not found for this venue', status: :not_found)
          return
        end
        
        if @booking.status_canceled?
          api_error(message: 'Booking is already canceled', status: :bad_request)
          return
        end
        
        reason = params[:reason] || 'Canceled by venue manager'
        @booking.cancel!
        @booking.update!(cancellation_reason: reason)
        
        api_success(
          data: {
            booking: detailed_booking_response(@booking)
          },
          message: 'Booking canceled successfully',
          status: :ok
        )
      end
      
      # GET /api/v1/venues/:venue_id/manager/blocklist/reasons
      # List available reasons for blocking a user
      def blocklist_reasons
        reasons = [
          { key: 'intrusive_behavior', label: 'Intrusive behavior', incident_type: 'behavior' },
          { key: 'no_show_without_notice', label: 'No-show without notice', incident_type: 'no_show' },
          { key: 'rude_behavior', label: 'Rude behavior', incident_type: 'behavior' },
          { key: 'booking_abuse', label: 'Booking abuse', incident_type: 'fraud' },
          { key: 'violation_event_rules', label: 'Violation of event rules', incident_type: 'behavior' },
          { key: 'non_payment', label: 'Non-payment', incident_type: 'fraud' },
          { key: 'other', label: 'Other reasons', incident_type: 'other' }
        ]

        api_success(
          data: {
            reasons: reasons,
            incident_types: %w[no_show late_cancellation behavior fraud other]
          },
          status: :ok
        )
      end

      # GET /api/v1/venues/:venue_id/events/:event_id/rsvps
      # List all RSVPs for an event
      def event_rsvps
        rsvps = @event.event_interests
                     .includes(:user)
                     .order(created_at: :desc)
        
        # Filter by RSVP status
        rsvps = rsvps.where(rsvp_status: params[:rsvp_status]) if params[:rsvp_status].present?
        
        # Filter by search term
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          rsvps = rsvps.joins(:user).where(
            "users.name ILIKE ? OR users.email ILIKE ?",
            search_term, search_term
          )
        end
        
        # Pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = rsvps.count
        rsvps = rsvps.limit(limit).offset(offset)
        
        api_success(
          data: {
            event: {
              id: @event.id,
              title: @event.title,
              starts_at: @event.starts_at
            },
            rsvps: rsvps.map { |rsvp| rsvp_response(rsvp) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            },
            stats: {
              total: @event.event_interests.count,
              yes: @event.event_interests.attending.count,
              no: @event.event_interests.not_attending.count,
              maybe: @event.event_interests.maybe_attending.count
            }
          },
          status: :ok
        )
      end
      
      # POST /api/v1/venues/:venue_id/events/:event_id/rsvps/:user_id/approve
      # Approve an RSVP (convert to booking if needed)
      def approve_rsvp
        rsvp = @event.event_interests.find_by(user_id: params[:user_id])
        
        unless rsvp
          api_error(message: 'RSVP not found', status: :not_found)
          return
        end
        
        # Update RSVP status to yes if not already
        rsvp.update!(rsvp_status: 'yes') unless rsvp.rsvp_status_yes?
        
        # Create booking if it doesn't exist and RSVP is yes
        booking = @event.bookings.find_or_initialize_by(user: rsvp.user)
        if booking.new_record?
          price = @event.price || 0.0
          currency = @event.currency || 'USD'
          booking.assign_attributes(
            status: @event.free? ? 'confirmed' : 'confirmed',
            price: price,
            currency: currency,
            payment_status: @event.free? ? 'paid' : 'pending'
          )
          booking.save!
        end
        
        api_success(
          data: {
            rsvp: rsvp_response(rsvp),
            booking: booking.persisted? ? detailed_booking_response(booking) : nil
          },
          message: 'RSVP approved successfully',
          status: :ok
        )
      end
      
      # POST /api/v1/venues/:venue_id/events/:event_id/rsvps/:user_id/block
      # Block an RSVP and add user to blocklist
      def block_rsvp
        rsvp = @event.event_interests.find_by(user_id: params[:user_id])
        
        unless rsvp
          api_error(message: 'RSVP not found', status: :not_found)
          return
        end
        
        reason = params[:reason] || 'RSVP blocked by venue manager'
        incident_type = params[:incident_type] || 'other'
        
        # Add user to blocklist
        blocklist = @venue.venue_blocklists.build(
          user: rsvp.user,
          blocked_by: current_user,
          reason: reason,
          description: params[:description],
          incident_type: incident_type,
          related_event_id: @event.id,
          is_permanent: params[:is_permanent] || false,
          blocked_until: params[:blocked_until]
        )
        
        if blocklist.save
          # Update RSVP to no
          rsvp.update!(rsvp_status: 'no')
          
          # Cancel any existing booking
          booking = @event.bookings.find_by(user: rsvp.user)
          booking&.cancel!
          
          api_success(
            data: {
              rsvp: rsvp_response(rsvp),
              blocklist: blocklist_response(blocklist)
            },
            message: 'RSVP blocked and user added to blocklist',
            status: :ok
          )
        else
          api_validation_error(errors: blocklist.errors.full_messages)
        end
      end
      
      # POST /api/v1/venues/:venue_id/events/:event_id/rsvps/:user_id/cancel
      # Cancel an RSVP
      def cancel_rsvp
        rsvp = @event.event_interests.find_by(user_id: params[:user_id])
        
        unless rsvp
          api_error(message: 'RSVP not found', status: :not_found)
          return
        end
        
        rsvp.update!(rsvp_status: 'no')
        
        # Cancel any existing booking
        booking = @event.bookings.find_by(user: rsvp.user)
        booking&.cancel!
        
        api_success(
          data: {
            rsvp: rsvp_response(rsvp)
          },
          message: 'RSVP canceled successfully',
          status: :ok
        )
      end
      
      private
      
      def require_venue_manager!
        return if current_user.role_admin?
        return if current_user.role_venue_manager?
        if params[:venue_id].present? && current_user.active_pr_partnerships.exists?(venue_id: params[:venue_id])
          return
        end
        if params[:venue_id].present? && VenueStaff.active.by_role('manager').exists?(venue_id: params[:venue_id], user_id: current_user.id)
          return
        end

        api_error(message: 'Venue manager access required', status: :forbidden)
        nil
      end

      def set_venue
        @venue = current_user.venues.find_by(id: params[:venue_id])

        unless @venue
          @venue = Venue.find_by(id: params[:venue_id]) if current_user.role_admin?
        end

        unless @venue
          pr = current_user.active_pr_partnerships.find_by(venue_id: params[:venue_id])
          @venue = pr&.venue
        end

        # Venue managers (staff) may not "own" the venue. Allow access via venue_staff assignment.
        unless @venue
          staff = VenueStaff.active.by_role('manager').find_by(venue_id: params[:venue_id], user_id: current_user.id)
          @venue = staff&.venue
        end

        unless @venue
          api_error(message: 'Venue not found or access denied', status: :not_found)
          nil
        end
      end
      
      def set_event
        @event = @venue.events.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def set_booking
        @booking = Booking.find_by(id: params[:booking_id])
        unless @booking
          api_error(message: 'Booking not found', status: :not_found)
          return
        end
      end
      
      def staff_params
        params.permit(:role, :status, :receives_notifications, :shift_start_at, :shift_end_at)
      end
      
      def venue_summary(venue)
        {
          id: venue.id,
          name: venue.name,
          city: venue.city,
          country: venue.country,
          total_events: venue.events.count,
          upcoming_events: venue.events.upcoming.count,
          active_staff: venue.venue_staff.active.count
        }
      end
      
      def event_summary(event)
        {
          id: event.id,
          title: event.title,
          starts_at: event.starts_at.iso8601,
          status: event.status,
          bookings_count: event.bookings_count,
          is_live: event.is_live?
        }
      end
      
      def order_summary(order)
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          order_type: order.order_type,
          total_amount: order.total_amount.to_f,
          customer: {
            name: order.user.name,
            table_number: order.booking&.table_number
          },
          items: order.food_bar_order_items.map do |item|
            {
              name: item.menu_item.name,
              quantity: item.quantity,
              special_instructions: item.special_instructions
            }
          end,
          special_instructions: order.special_instructions,
          allergies: order.allergies,
          ordered_at: order.ordered_at&.iso8601,
          time_elapsed: order.ordered_at ? ((Time.current - order.ordered_at) / 60).round : 0
        }
      end

      def build_tables_from_orders(orders_query, table_index = nil)
        tables = {}
        orders_query.each do |order|
          table_number = order.table_number
          table = table_index ? table_index[table_number] : nil
          tables[table_number] ||= default_table_entry(table_number: table_number, table: table)

          if order.payment_paid?
            tables[table_number][:paid_amount] += order.total_amount
          else
            tables[table_number][:unpaid_amount] += order.total_amount
            tables[table_number][:has_unpaid_orders] = true
          end

          tables[table_number][:total_amount] += order.total_amount

          if order.status.in?(['pending', 'confirmed', 'preparing'])
            tables[table_number][:has_pending_orders] = true
          end

          items_count = order.food_bar_order_items.sum(&:quantity)
          tables[table_number][:items_count] += items_count
          tables[table_number][:orders] << {
            id: order.id,
            order_number: order.order_number,
            status: order.status,
            payment_status: order.payment_status,
            total_amount: order.total_amount.to_f,
            is_split_bill: order.is_split_bill,
            items_count: items_count,
            ordered_at: order.ordered_at&.iso8601
          }
        end

        tables
      end

      def default_table_entry(table_number:, table: nil)
        data = {
          table_number: table_number,
          orders: [],
          items_count: 0,
          total_amount: 0,
          paid_amount: 0,
          unpaid_amount: 0,
          status: 'available', # available, occupied, waiting_payment, in_service
          has_pending_orders: false,
          has_unpaid_orders: false
        }

        return data unless table

        data.merge!(
          table_id: table.id,
          table_name: table.table_name,
          table_type: table.table_type,
          shape: table.shape,
          min_capacity: table.min_capacity,
          max_capacity: table.max_capacity,
          is_accessible: table.is_accessible,
          is_active: table.is_active,
          is_bookable: table.is_bookable,
          color: table.color,
          floor_plan_id: table.floor_plan&.id,
          floor_plan_zone_id: table.floor_plan_zone_id
        )
      end

      def tables_for_venue_overview
        floor_plans = @venue.floor_plans.active
        floor_plans = @venue.floor_plans if floor_plans.none?

        Table.joins(floor_plan_zone: :floor_plan)
             .where(floor_plans: { id: floor_plans.select(:id) })
             .includes(:floor_plan)
      end

      def apply_table_statuses!(tables)
        tables.each_value do |table_data|
          if table_data[:has_unpaid_orders]
            table_data[:status] = 'waiting_payment'
          elsif table_data[:has_pending_orders]
            table_data[:status] = 'in_service'
          elsif table_data[:orders].any?
            table_data[:status] = 'occupied'
          else
            table_data[:status] = 'available'
          end
        end
      end

      def booking_table_response(booking)
        {
          id: booking.id,
          status: booking.status,
          payment_status: booking.payment_status,
          table_number: booking.table_number,
          user: {
            id: booking.user.id,
            name: booking.user.name
          },
          event: {
            id: booking.event.id,
            title: booking.event.title,
            starts_at: booking.event.starts_at&.iso8601
          },
          checked_in_at: booking.checked_in_at&.iso8601,
          booked_at: booking.created_at.iso8601
        }
      end

      def booking_overview_response(booking)
        {
          id: booking.id,
          status: booking.status,
          payment_status: booking.payment_status,
          user: {
            id: booking.user.id,
            name: booking.user.name
          },
          checked_in_at: booking.checked_in_at&.iso8601
        }
      end

      def table_summary(table)
        return nil unless table

        {
          id: table.id,
          table_number: table.table_number,
          table_name: table.table_name,
          table_type: table.table_type,
          shape: table.shape,
          min_capacity: table.min_capacity,
          max_capacity: table.max_capacity,
          is_accessible: table.is_accessible,
          is_active: table.is_active,
          is_bookable: table.is_bookable,
          color: table.color,
          floor_plan_id: table.floor_plan&.id,
          floor_plan_zone_id: table.floor_plan_zone_id
        }
      end
      
      def staff_response(staff)
        {
          id: staff.id,
          user: {
            id: staff.user.id,
            name: staff.user.name,
            email: staff.user.email,
            phone: staff.user.phone
          },
          role: staff.role,
          status: staff.status,
          receives_notifications: staff.receives_notifications,
          on_shift: staff.on_shift?,
          last_location_update: staff.last_location_update&.iso8601,
          shift_start_at: staff.shift_start_at&.iso8601,
          shift_end_at: staff.shift_end_at&.iso8601
        }
      end
      
      def call_summary(call)
        {
          id: call.id,
          call_type: call.call_type,
          status: call.status,
          customer: {
            id: call.user.id,
            name: call.user.name
          },
          table_number: call.table_number,
          location: call.location_description,
          message: call.message,
          time_waiting: call.time_waiting.round,
          created_at: call.created_at.iso8601
        }
      end
      
      def period_to_since(period)
        case period.to_s.downcase
        when 'weekly' then 1.week.ago
        when 'monthly' then 1.month.ago
        when '6months', '6_months' then 6.months.ago
        when '1year', '1_year', 'yearly' then 1.year.ago
        else 1.month.ago
        end
      end

      def calculate_revenue(venue, since)
        bookings_revenue = Booking.joins(:event)
                                  .where(events: { venue_id: venue.id })
                                  .where('bookings.created_at >= ?', since)
                                  .paid
                                  .sum(:price)
        
        orders_revenue = FoodBarOrder.joins(:event)
                                     .where(events: { venue_id: venue.id })
                                     .where('food_bar_orders.created_at >= ?', since)
                                     .where(payment_status: 'paid')
                                     .sum(:total_amount)
        
        {
          total: (bookings_revenue + orders_revenue).to_f,
          from_bookings: bookings_revenue.to_f,
          from_orders: orders_revenue.to_f
        }
      end

      def top_menu_items(venue, since, limit = 10)
        FoodBarOrderItem.joins(food_bar_order: :event, menu_item: :menu_category)
                        .where(events: { venue_id: venue.id })
                        .where('food_bar_order_items.created_at >= ?', since)
                        .group('menu_items.id', 'menu_items.name')
                        .select('menu_items.id, menu_items.name, SUM(food_bar_order_items.quantity) as total_sold, SUM(food_bar_order_items.total_price) as revenue')
                        .order('total_sold DESC')
                        .limit(limit)
                        .map do |item|
          {
            menu_item_id: item.id,
            name: item.name,
            quantity_sold: item.total_sold,
            revenue: item.revenue.to_f
          }
        end
      end
      
      def participant_response(booking)
        {
          id: booking.id,
          user: {
            id: booking.user.id,
            name: booking.user.name,
            email: booking.user.email,
            phone: booking.user.phone
          },
          status: booking.status,
          table_number: booking.table_number,
          checked_in_at: booking.checked_in_at&.iso8601,
          payment_status: booking.payment_status,
          cancellation_requested: booking.cancellation_requested,
          cancellation_reason: booking.cancellation_reason,
          vibe_check_submitted: booking.vibe_check.present?,
          vibe_check_rating: booking.vibe_check&.overall_rating,
          created_at: booking.created_at.iso8601
        }
      end
      
      def cancellation_request_response(booking)
        {
          id: booking.id,
          user: {
            id: booking.user.id,
            name: booking.user.name,
            email: booking.user.email
          },
          cancellation_requested_at: booking.cancellation_requested_at.iso8601,
          cancellation_reason: booking.cancellation_reason,
          refund_amount: booking.cancellation_refund_amount.to_f,
          cancellation_fee: booking.cancellation_fee_amount.to_f,
          booking_price: booking.price.to_f
        }
      end
      
      def table_order_response(order)
        items = order.food_bar_order_items.map do |item|
          {
            name: item.menu_item.name,
            quantity: item.quantity,
            price: item.total_price.to_f
          }
        end
        items_count = items.sum { |item| item[:quantity].to_i }
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          payment_status: order.payment_status,
          order_type: order.order_type,
          total_amount: order.total_amount.to_f,
          is_split_bill: order.is_split_bill,
          customer: {
            id: order.user.id,
            name: order.user.name
          },
          items_count: items_count,
          items: items,
          splits: order.is_split_bill? ? order.bill_splits.map do |split|
            {
              participant: split.user ? split.user.name : split.split_name,
              amount: split.split_amount.to_f,
              payment_status: split.payment_status
            }
          end : [],
          ordered_at: order.ordered_at&.iso8601,
          time_elapsed: order.ordered_at ? ((Time.current - order.ordered_at) / 60).round : 0
        }
      end
      
      def blocklist_response(blocklist)
        {
          id: blocklist.id,
          user: {
            id: blocklist.user.id,
            name: blocklist.user.name,
            email: blocklist.user.email
          },
          reason: blocklist.reason,
          description: blocklist.description,
          incident_type: blocklist.incident_type,
          is_permanent: blocklist.is_permanent,
          blocked_until: blocklist.blocked_until&.iso8601,
          active: blocklist.active?,
          time_remaining_hours: blocklist.time_remaining,
          blocked_by: {
            id: blocklist.blocked_by.id,
            name: blocklist.blocked_by.name
          },
          created_at: blocklist.created_at.iso8601
        }
      end
      
      def detailed_booking_response(booking, include_full_details: false)
        # Get RSVP info if exists
        event_interest = booking.event.event_interests.find_by(user: booking.user)
        
        # Get preorders (food/bar orders)
        preorders = booking.food_bar_orders.includes(:food_bar_order_items => :menu_item)
        
        response = {
          id: booking.id,
          booking_id: booking.id, # For display like "#: 456-234-LK-djdjk"
          chat_id: booking_assigned_pr_chat_id(booking),
          status: booking.status,
          payment_status: booking.payment_status,
          price: booking.price.to_f,
          total_price: booking.price.to_f,
          original_price: booking.respond_to?(:original_price) ? booking.original_price&.to_f : nil,
          discount_amount: booking.respond_to?(:discount_amount) ? booking.discount_amount&.to_f : nil,
          promo_code: booking.respond_to?(:promo_code) && booking.promo_code ? (booking.promo_code.respond_to?(:code) ? booking.promo_code.code : booking.promo_code.to_s) : nil,
          currency: booking.currency,
          payment_method: booking.payment_method,
          paid_at: booking.paid_at&.iso8601,
          payment_type: booking.respond_to?(:payment_type) ? booking.payment_type : nil,
          paid_amount: booking.paid_amount&.to_f,
          remaining_amount: booking.remaining_amount.to_f,
          payment_progress_percentage: booking.payment_progress_percentage.to_s,
          fully_paid: booking.fully_paid?,
          partially_paid: booking.partially_paid?,
          is_free: booking.free?,
          requires_payment: booking.requires_payment?,
          table_number: booking.table_number,
          seats: booking.table_number ? "Table #{booking.table_number}" : nil,
          notes: booking.notes,
          attendees: {
            adults_count: booking.adults_count || 0,
            children_count: booking.children_count || 0,
            infants_count: booking.infants_count || 0,
            pets_count: booking.pets_count || 0,
            total_count: booking.total_attendees_count
          },
          user: {
            id: booking.user.id,
            name: booking.user.name,
            username: booking.user.username,
            email: booking.user.email,
            phone: booking.user.phone,
            avatar_url: booking.user.respond_to?(:avatar_url) && booking.user.avatar_url.present? ? booking.user.avatar_url : default_avatar_url
          },
          event: {
            id: booking.event.id,
            title: booking.event.title,
            starts_at: booking.event.starts_at&.iso8601,
            ends_at: booking.event.ends_at&.iso8601,
            address: booking.event.venue.full_address,
            attendance_mode: booking.event.attendance_mode
          },
          guests: {
            total: event_interest ? (event_interest.guest_count + 1) : 1,
            guest_count: event_interest&.guest_count || 0,
            # For display: "2 adult, 1 children, 1 infant" - simplified for now
            breakdown: event_interest ? "#{event_interest.guest_count} guest(s)" : "0 guests"
          },
          preorder: {
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
                time_window_start: order.time_window_start&.iso8601,
                time_window_end: order.time_window_end&.iso8601,
                items: order.food_bar_order_items.map do |item|
                  {
                    name: item.menu_item.name,
                    quantity: item.quantity,
                    price: item.total_price.to_f
                  }
                end
              }
            end
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
          checked_in_at: booking.checked_in_at&.iso8601,
          created_at: booking.created_at.iso8601,
          updated_at: booking.updated_at.iso8601,
          # Flat flags for list UIs (highlight “my” bookings vs unassigned)
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
        
        if include_full_details
          response.merge!(
            payment_details: {
              transaction_id: booking.payment_transaction_id,
              refund_amount: booking.refund_amount&.to_f,
              cancellation_fee: booking.cancellation_fee&.to_f
            },
            vibe_check: booking.vibe_check ? {
              submitted: true,
              rating: booking.vibe_check.overall_rating,
              submitted_at: booking.vibe_check.created_at&.iso8601
            } : { submitted: false }
          )
        end
        
        response
      end

      # Returns (and creates if needed) the 1:1 booking-scoped chat id between the booking user
      # and the assigned PR user. Nil when booking is unassigned.
      def booking_assigned_pr_chat_id(booking)
        pr_user = booking.assigned_pr_user
        return nil unless pr_user

        user1_id, user2_id = [booking.user_id, pr_user.id].sort
        chat = Chat.find_by(user1_id: user1_id, user2_id: user2_id, booking_id: booking.id)
        return chat.id if chat

        Chat.create!(user1_id: user1_id, user2_id: user2_id, booking_id: booking.id).id
      rescue ActiveRecord::RecordInvalid
        Chat.find_by(user1_id: user1_id, user2_id: user2_id, booking_id: booking.id)&.id
      end
      
      def notify_user_booking_confirmed(booking)
        return unless booking&.user && booking.event

        Notification.create!(
          user: booking.user,
          notification_type: 'booking_confirmed',
          title: 'Booking confirmed',
          message: "Your booking for \"#{booking.event.title}\" has been confirmed by the venue.",
          metadata: {
            booking_id: booking.id,
            event_id: booking.event.id,
            event_title: booking.event.title,
            venue_name: booking.event.venue&.name
          }
        )

        return unless FcmService.configured?
        FcmService.send_to_user(
          booking.user,
          title: 'Booking confirmed',
          body: "Your booking for \"#{booking.event.title}\" has been confirmed.",
          data: {
            notification_type: 'booking_confirmed',
            booking_id: booking.id.to_s,
            event_id: booking.event.id.to_s
          }
        )
      rescue => e
        Rails.logger.error "Failed to notify user of booking confirmation: #{e.message}"
      end

      def notify_user_booking_rejected(booking, reason)
        return unless booking&.user && booking.event

        Notification.create!(
          user: booking.user,
          notification_type: 'booking_cancelled',
          title: 'Booking rejected',
          message: "Your booking for \"#{booking.event.title}\" was rejected. #{reason}",
          metadata: {
            booking_id: booking.id,
            event_id: booking.event.id,
            event_title: booking.event.title,
            rejection_reason: reason
          }
        )

        return unless FcmService.configured?
        FcmService.send_to_user(
          booking.user,
          title: 'Booking rejected',
          body: "Your booking for \"#{booking.event.title}\" was rejected.",
          data: {
            notification_type: 'booking_cancelled',
            booking_id: booking.id.to_s,
            event_id: booking.event.id.to_s
          }
        )
      rescue => e
        Rails.logger.error "Failed to notify user of booking rejection: #{e.message}"
      end

      def rsvp_response(rsvp)
        {
          id: rsvp.id,
          user: {
            id: rsvp.user.id,
            name: rsvp.user.name,
            username: rsvp.user.username,
            email: rsvp.user.email,
            phone: rsvp.user.phone,
            avatar_url: rsvp.user.respond_to?(:avatar_url) && rsvp.user.avatar_url.present? ? rsvp.user.avatar_url : default_avatar_url
          },
          rsvp_status: rsvp.rsvp_status,
          guest_count: rsvp.guest_count,
          total_attendees: rsvp.total_attendees,
          notes: rsvp.notes,
          responded_at: rsvp.responded_at&.iso8601,
          created_at: rsvp.created_at.iso8601,
          has_booking: rsvp.event.bookings.exists?(user: rsvp.user)
        }
      end
    end
  end
end

