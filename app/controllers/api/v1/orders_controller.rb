module Api
  module V1
    class OrdersController < ApplicationController
      before_action :require_authentication!, except: [:split_qr_image]
      before_action :set_event, only: [:create, :event_orders]
      before_action :set_order, only: [:show, :cancel, :add_tip, :create_split, :pay_split, :list_splits, :update_splits, :create_split_qr]
      before_action :check_order_ownership, only: [:cancel, :add_tip]
      
      # GET /api/v1/orders/my_orders
      def my_orders
        orders = current_user.food_bar_orders
                            .includes(:event, :food_bar_order_items => :menu_item)
                            .recent
        
        # Filter by event if provided
        orders = orders.where(event_id: params[:event_id]) if params[:event_id].present?
        
        # Filter by status
        orders = orders.by_status(params[:status]) if params[:status].present?
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = orders.count
        orders = orders.limit(limit).offset(offset)
        
        api_success(
          data: {
            orders: orders.map { |order| order_response(order, include_event: true, detailed: true) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          }
        )
      end
      
      # GET /api/v1/events/:event_id/orders
      def event_orders
        # Only venue owners/staff can see all orders
        unless @event.creator_id == current_user.id || current_user.role_admin?
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        orders = @event.food_bar_orders
                       .includes(:user, :food_bar_order_items => :menu_item)
                       .recent
        
        orders = orders.by_status(params[:status]) if params[:status].present?
        
        api_success(data: { orders: orders.map { |order| order_response(order, include_user: true) } })
      end
      
      # GET /api/v1/orders/:id
      def show
        unless can_view_order?(@order)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        api_success(data: { order: order_response(@order, detailed: true) })
      end
      
      # POST /api/v1/events/:event_id/orders
      def create
        unless @event.has_active_menus?
          unless ensure_event_menus_from_venue!(@event)
            api_error(message: 'No menu available for this event', status: :bad_request)
            return
          end
        end
        
        booking = current_user.bookings.find_by(event: @event)
        
        time_window_start = parse_time_param(params[:time_window_start])
        time_window_end = parse_time_param(params[:time_window_end])
        if time_window_start == :invalid || time_window_end == :invalid
          api_error(message: 'Invalid order time window', status: :bad_request)
          return
        end

        order = @event.food_bar_orders.build(
          user: current_user,
          booking: booking,
          order_type: params[:order_type] || 'both',
          table_number: params[:table_number] || booking&.table_number,
          special_instructions: params[:special_instructions],
          allergies: params[:allergies] || params[:allergies_note],
          dietary_restrictions: params[:dietary_restrictions],
          tip_amount: params[:tip_amount]&.to_f || 0,
          tip_percentage: params[:tip_percentage]&.to_f,
          currency: 'USD',
          time_window_start: time_window_start,
          time_window_end: time_window_end
        )
        
        # Add order items
        items_params = params[:items] || []
        subtotal = 0
        
        items_params.each do |item_param|
          menu_item = resolve_menu_item_for_event(@event, item_param[:menu_item_id])
          unless menu_item
            api_error(message: 'Menu item not found for this event', status: :not_found)
            return
          end
          
          unless menu_item.is_available
            api_error(message: "#{menu_item.name} is currently unavailable", status: :bad_request)
            return
          end
          
          order_item = order.food_bar_order_items.build(
            menu_item: menu_item,
            quantity: item_param[:quantity] || 1,
            unit_price: menu_item.price,
            special_instructions: item_param[:special_instructions],
            customizations: item_param[:customizations]&.to_json
          )
          
          item_total = order_item.total_price
          if item_total.nil?
            item_total = (order_item.unit_price || menu_item.price) * order_item.quantity
          end
          subtotal += item_total
        end
        
        # Calculate tax
        order.subtotal = subtotal
        order.tax = (subtotal * 0.08).round(2) # Default 8% tax, can be configured per event
        
        if order.save
          order.update!(ordered_at: Time.current)
          
          api_success(
            data: { order: order_response(order, detailed: true) },
            message: 'Order placed successfully',
            status: :created
          )
        else
          api_validation_error(errors: order.errors.full_messages)
        end
      end
      
      # POST /api/v1/orders/:id/cancel
      def cancel
        unless @order.status_pending? || @order.status_confirmed?
          api_error(message: 'Order cannot be canceled at this stage', status: :bad_request)
          return
        end
        
        @order.cancel!
        
        api_success(
          data: { order: order_response(@order) },
          message: 'Order canceled successfully'
        )
      end
      
      # POST /api/v1/orders/:id/add_tip
      def add_tip
        tip_amount = params[:tip_amount].to_f
        
        unless tip_amount >= 0
          api_error(message: 'Tip amount must be positive', status: :bad_request)
          return
        end
        
        @order.update!(tip_amount: tip_amount)
        
        api_success(
          data: { order: order_response(@order) },
          message: 'Tip added successfully'
        )
      end
      
      # POST /api/v1/orders/:id/split_qr
      def create_split_qr
        if @order.is_split_bill?
          api_error(message: 'Order is already split', status: :bad_request)
          return
        end
        
        max_participants = params[:max_participants]&.to_i
        
        qr_code = @order.generate_split_qr_code!(max_participants: max_participants)
        
        api_success(
          data: {
            qr_code: {
              id: qr_code.id,
              token: qr_code.qr_token,
              qr_url: qr_code.qr_url,
              qr_image_url: qr_code.qr_image_url,
              qr_data: qr_code.qr_data,
              type: "Split",
              current_participants: qr_code.current_participants,
              max_participants: qr_code.max_participants,
              expires_at: qr_code.expires_at.iso8601,
              status: qr_code.status
            },
            order: {
              id: @order.id,
              order_number: @order.order_number,
              total_amount: @order.total_amount.to_f
            }
          },
          message: 'QR code generated. Share with friends to split the bill.'
        )
      end
      
      # GET /api/v1/orders/split_qr/:qr_token/image
      def split_qr_image
        qr_code = SplitQrCode.find_by(qr_token: params[:qr_token])
        
        unless qr_code
          api_error(message: 'QR code not found', status: :not_found)
          return
        end
        
        if qr_code.expired?
          api_error(message: 'QR code has expired', status: :bad_request)
          return
        end
        
        # Generate QR code image
        qr_image_base64 = qr_code.generate_qr_image_base64
        
        # Return as PNG image
        send_data(
          Base64.decode64(qr_image_base64),
          type: 'image/png',
          disposition: 'inline',
          filename: "split_qr_#{qr_code.qr_token}.png"
        )
      rescue => e
        Rails.logger.error "Split QR Image Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to generate QR code image', status: :internal_server_error)
      end
      
      # POST /api/v1/orders/join_split/:qr_token
      def join_split_by_qr
        qr_code = SplitQrCode.find_by(qr_token: params[:qr_token])
        
        unless qr_code
          api_error(message: 'Invalid QR code', status: :not_found)
          return
        end

        if qr_code.expired?
          api_error(message: 'QR code has expired', status: :bad_request)
          return
        end

        # Add current user to split
        participant = {
          user_id: current_user.id
        }

        if qr_code.add_participant!(current_user)
          order = qr_code.food_bar_order
          
          # Get user's split
          user_split = order.bill_splits.find_by(user_id: current_user.id)
          
          unless user_split
            api_error(message: 'Failed to create split for user', status: :unprocessable_entity)
            return
          end

          # Create PaymentIntent for the user's split amount (if not already paid)
          payment_intent_data = nil
          if user_split.payment_status_pending? && user_split.split_amount > 0
            provider = params[:provider] || 'stripe'
            provider_config = PaymentProvider.active_lookup(provider)
            
            if provider_config
              # Create PaymentTransaction record
              wallet = current_user.wallets.find_or_create_by!(currency: order.currency) do |w|
                w.status = 'active'
                w.balance = 0
                w.locked_balance = 0
              end

              transaction = PaymentTransaction.create!(
                wallet: wallet,
                user: current_user,
                transaction_type: 'payment',
                status: 'pending',
                amount: user_split.split_amount,
                currency: order.currency,
                payment_method: 'credit_card',
                payment_provider: provider,
                reference: user_split,
                metadata: {
                  order_id: order.id,
                  order_number: order.order_number,
                  split_id: user_split.id,
                  qr_token: params[:qr_token]
                }.to_json
              )

              # Create Payment Intent via Stripe
              stripe_provider = StripePaymentProvider.new(provider_config)
              
              stripe_metadata = {
                user_id: current_user.id,
                reference_type: 'BillSplit',
                reference_id: user_split.id,
                order_id: order.id,
                order_number: order.order_number,
                split_id: user_split.id,
                qr_token: params[:qr_token]
              }

              result = stripe_provider.create_payment_intent(
                amount: user_split.split_amount,
                currency: order.currency,
                transaction_id: transaction.id,
                metadata: stripe_metadata,
                customer_id: params[:customer_id],
                payment_method_id: params[:payment_method_id]
              )

              # Update transaction with payment intent ID
              transaction.update!(
                provider_transaction_id: result[:payment_intent_id],
                provider_response: result.to_json
              )

              payment_intent_data = {
                payment_intent_id: result[:payment_intent_id],
                client_secret: result[:client_secret],
                transaction_id: transaction.id,
                status: result[:status],
                amount: result[:amount],
                currency: result[:currency]
              }
            end
          end

          response_data = {
            order: order_response(order, detailed: true),
            your_split: split_response(user_split),
            qr_code: {
              current_participants: qr_code.current_participants,
              max_participants: qr_code.max_participants
            }
          }
          
          # Include payment intent if created
          if payment_intent_data
            response_data[:payment_intent] = payment_intent_data
          end

          api_success(
            data: response_data,
            message: "You've joined the split! Your share is #{user_split.split_amount} #{order.currency}"
          )
        else
          api_error(message: 'Failed to join split. Maximum participants reached or split is inactive.', status: :unprocessable_entity)
        end
      rescue PaymentService::InvalidProviderError => e
        api_error(message: e.message, status: :bad_request)
      rescue => e
        Rails.logger.error "Join split error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: "Failed to join split: #{e.message}", status: :unprocessable_entity)
      end
      
      # POST /api/v1/orders/:id/split
      def create_split
        participants = params[:participants] || params[:user_ids] || []
        
        # Ensure current user is included
        has_current_user = participants.any? do |p|
          p.is_a?(Hash) ? p[:user_id] == current_user.id.to_s : p == current_user.id.to_s
        end
        
        participants << { user_id: current_user.id } unless has_current_user
        
        if participants.size < 2
          api_error(message: 'Split bill requires at least 2 participants', status: :bad_request)
          return
        end
        
        if @order.is_split_bill?
          api_error(message: 'Order is already split', status: :bad_request)
          return
        end
        
        if @order.create_splits!(participants)
          api_success(
            data: { 
              order: order_response(@order, detailed: true),
              splits: @order.bill_splits.map { |split| split_response(split) }
            },
            message: 'Bill split created successfully'
          )
        else
          api_error(message: 'Failed to create split', status: :unprocessable_entity)
        end
      end
      
      # POST /api/v1/orders/:id/splits/:split_id/pay
      def pay_split
        split = @order.bill_splits.find(params[:split_id])
        
        unless split.user_id == current_user.id
          api_error(message: 'You can only pay your own split', status: :forbidden)
          return
        end
        
        if split.payment_status_paid?
          api_error(message: 'Split is already paid', status: :bad_request)
          return
        end
        
        # Process payment
        payment_service = PaymentService.new(current_user, params[:provider])
        result = payment_service.process_payment(
          amount: split.split_amount,
          currency: split.currency,
          payment_method: params[:payment_method],
          reference: split,
          metadata: {
            order_id: @order.id,
            order_number: @order.order_number,
            split_id: split.id
          }
        )
        
        if result[:success]
          split.mark_as_paid!(result[:transaction])
          
          api_success(
            data: {
              split: split_response(split),
              order: order_response(@order)
            },
            message: 'Payment processed successfully'
          )
        else
          split.mark_as_failed!
          api_error(
            message: result[:error] || 'Payment failed',
            status: :unprocessable_entity
          )
        end
      end

      # GET /api/v1/orders/:id/splits
      def list_splits
        unless can_view_order?(@order)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        api_success(
          data: {
            order: {
              id: @order.id,
              order_number: @order.order_number,
              total_amount: @order.total_amount.to_f,
              currency: @order.currency,
              is_split_bill: @order.is_split_bill,
              split_count: @order.split_count
            },
            splits: @order.bill_splits.map { |split| split_response(split) }
          },
          status: :ok
        )
      end

      # PATCH /api/v1/orders/:id/splits
      def update_splits
        unless @order.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only the order owner can update split amounts', status: :forbidden)
          return
        end

        unless @order.is_split_bill?
          api_error(message: 'Order is not split', status: :bad_request)
          return
        end

        split_params = params[:splits] || []
        unless split_params.is_a?(Array) && split_params.any?
          api_error(message: 'splits is required', status: :bad_request)
          return
        end

        order_splits = @order.bill_splits.to_a
        if split_params.size != order_splits.size
          api_error(message: 'Provide all splits to update amounts', status: :bad_request)
          return
        end

        updates = []
        split_params.each do |split_param|
          split_id = split_param[:id] || split_param['id']
          amount = split_param[:split_amount] || split_param['split_amount']
          split = order_splits.find { |s| s.id.to_s == split_id.to_s }
          unless split
            api_error(message: 'Split not found for this order', status: :not_found)
            return
          end
          if split.payment_status_paid?
            api_error(message: 'Cannot modify a paid split', status: :unprocessable_entity)
            return
          end
          updates << { split: split, amount: amount.to_f }
        end

        total = updates.sum { |item| item[:amount] }
        if total.round(2) != @order.total_amount.to_f.round(2)
          api_error(message: 'Split amounts must equal total order amount', status: :unprocessable_entity)
          return
        end

        BillSplit.transaction do
          updates.each do |item|
            item[:split].update!(split_amount: item[:amount])
          end
        end

        api_success(
          data: {
            order: {
              id: @order.id,
              order_number: @order.order_number,
              total_amount: @order.total_amount.to_f,
              currency: @order.currency,
              is_split_bill: @order.is_split_bill,
              split_count: @order.split_count
            },
            splits: @order.bill_splits.map { |split| split_response(split) }
          },
          message: 'Split amounts updated successfully',
          status: :ok
        )
      end
      
      private
      
      def set_event
        @event = Event.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
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
      
      def set_order
        @order = FoodBarOrder.find_by(id: params[:id])
        unless @order
          api_error(message: 'Order not found', status: :not_found)
          return
        end
      end
      
      def check_order_ownership
        unless @order.user_id == current_user.id
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
      end
      
      def can_view_order?(order)
        order.user_id == current_user.id ||
        order.event.creator_id == current_user.id ||
        order.bill_splits.exists?(user_id: current_user.id) ||
        current_user.role_admin?
      end
      
      def order_response(order, include_event: false, include_user: false, detailed: false)
        response = {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          order_type: order.order_type,
          subtotal: order.subtotal.to_f,
          tax: order.tax.to_f,
          tip_amount: order.tip_amount.to_f,
          tip_percentage: order.tip_percentage&.to_f,
          total_amount: order.total_amount.to_f,
          currency: order.currency,
          payment_status: order.payment_status,
          is_split_bill: order.is_split_bill,
          split_count: order.split_count,
          special_instructions: order.special_instructions,
          allergies: order.allergies,
          dietary_restrictions: order.dietary_restrictions,
          ordered_at: order.ordered_at&.iso8601,
          time_window_start: order.time_window_start&.iso8601,
          time_window_end: order.time_window_end&.iso8601,
          created_at: order.created_at.iso8601
        }
        
        if include_event
          response[:event] = {
            id: order.event.id,
            title: order.event.title,
            starts_at: order.event.starts_at
          }
        end
        
        if include_user
          response[:user] = {
            id: order.user.id,
            name: order.user.name,
            email: order.user.email
          }
        end
        
        if detailed
          response[:items] = order.food_bar_order_items.map { |item| order_item_response(item) }
          
          if order.is_split_bill?
            response[:splits] = order.bill_splits.map { |split| split_response(split) }
          end
        end
        
        response
      end
      
      def order_item_response(item)
        {
          id: item.id,
          menu_item: {
            id: item.menu_item.id,
            name: item.menu_item.name,
            description: item.menu_item.description,
            image_url: attachment_url(item.menu_item.image) || item.menu_item.image_url
          },
          quantity: item.quantity,
          unit_price: item.unit_price.to_f,
          total_price: item.total_price.to_f,
          special_instructions: item.special_instructions,
          customizations: item.customizations_hash
        }
      end

      def attachment_url(attachment)
        return nil unless attachment&.attached?

        Rails.application.routes.url_helpers.rails_blob_url(attachment, host: request.base_url)
      end
      
      def split_response(split)
        {
          id: split.id,
          participant: if split.user
            {
              id: split.user.id,
              name: split.user.name,
              email: split.user.email,
              profile_picture_url: split.user.avatar_url,
              image: split.user.avatar_url
            }
          else
            {
              name: split.split_name,
              email: split.split_email,
              phone: split.split_phone
            }
          end,
          split_amount: split.split_amount.to_f,
          payment_status: split.payment_status,
          paid_at: split.paid_at&.iso8601
        }
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

