module Api
  module V1
    class WaiterCallsController < ApplicationController
      before_action :require_authentication!
      before_action :set_event, only: [:create]
      before_action :set_waiter_call, only: [:show, :cancel, :acknowledge, :complete]
      
      # POST /api/v1/events/:event_id/call_waiter
      def create
        waiter_call = @event.waiter_calls.build(
          user: current_user,
          booking: current_user.bookings.find_by(event: @event),
          order_id: params[:order_id],
          call_type: params[:call_type] || 'assistance',
          message: params[:message],
          table_number: params[:table_number],
          location_description: params[:location_description],
          user_latitude: params[:latitude],
          user_longitude: params[:longitude]
        )
        
        if waiter_call.save
          api_success(
            data: { 
              waiter_call: waiter_call_response(waiter_call),
              nearby_staff_notified: waiter_call.event.venue.venue_staff.active.count
            },
            message: 'Waiter called successfully. Nearby staff have been notified.',
            status: :created
          )
        else
          api_validation_error(errors: waiter_call.errors.full_messages)
        end
      end
      
      # GET /api/v1/waiter_calls/:id
      def show
        unless can_view_call?(@waiter_call)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        api_success(data: { waiter_call: waiter_call_response(@waiter_call, detailed: true) })
      end
      
      # GET /api/v1/waiter_calls/my_calls
      def my_calls
        calls = current_user.waiter_calls.includes(:event).recent
        
        calls = calls.where(status: params[:status]) if params[:status].present?
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        
        api_success(
          data: {
            calls: calls.limit(limit).offset(offset).map { |call| waiter_call_response(call, include_event: true) }
          }
        )
      end
      
      # GET /api/v1/events/:event_id/waiter_calls (Venue staff only)
      def event_calls
        event = Event.find(params[:event_id])
        
        unless event.creator_id == current_user.id || 
               event.venue.venue_staff.exists?(user_id: current_user.id) ||
               current_user.role_admin?
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        calls = event.waiter_calls.includes(:user).recent
        calls = calls.where(status: params[:status]) if params[:status].present?
        
        api_success(
          data: {
            calls: calls.map { |call| waiter_call_response(call, include_user: true) }
          }
        )
      end
      
      # POST /api/v1/waiter_calls/:id/acknowledge (Staff only)
      def acknowledge
        staff = current_user.venue_staff_assignments.find_by(venue_id: @waiter_call.event.venue_id)
        
        unless staff&.available_for_calls?
          api_error(message: 'Only active venue staff can acknowledge calls', status: :forbidden)
          return
        end
        
        @waiter_call.acknowledge!(staff)
        
        api_success(
          data: { waiter_call: waiter_call_response(@waiter_call) },
          message: 'Call acknowledged'
        )
      end
      
      # POST /api/v1/waiter_calls/:id/complete (Staff only)
      def complete
        unless @waiter_call.assigned_staff&.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only assigned staff can complete calls', status: :forbidden)
          return
        end
        
        @waiter_call.complete!
        
        api_success(
          data: { waiter_call: waiter_call_response(@waiter_call) },
          message: 'Call completed'
        )
      end
      
      # POST /api/v1/waiter_calls/:id/cancel
      def cancel
        unless @waiter_call.user_id == current_user.id
          api_error(message: 'You can only cancel your own calls', status: :forbidden)
          return
        end
        
        @waiter_call.cancel!
        
        api_success(
          data: { waiter_call: waiter_call_response(@waiter_call) },
          message: 'Call canceled'
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
      
      def set_waiter_call
        @waiter_call = WaiterCall.find_by(id: params[:id])
        unless @waiter_call
          api_error(message: 'Waiter call not found', status: :not_found)
          return
        end
      end
      
      def can_view_call?(call)
        call.user_id == current_user.id ||
        call.assigned_staff&.user_id == current_user.id ||
        call.event.creator_id == current_user.id ||
        call.event.venue.venue_staff.exists?(user_id: current_user.id) ||
        current_user.role_admin?
      end
      
      def waiter_call_response(call, include_event: false, include_user: false, detailed: false)
        response = {
          id: call.id,
          call_type: call.call_type,
          status: call.status,
          table_number: call.table_number,
          location_description: call.location_description,
          message: call.message,
          time_waiting: call.time_waiting.round,
          created_at: call.created_at.iso8601
        }
        
        if include_event
          response[:event] = {
            id: call.event.id,
            title: call.event.title,
            starts_at: call.event.starts_at
          }
        end
        
        if include_user
          response[:user] = {
            id: call.user.id,
            name: call.user.name
          }
        end
        
        if detailed
          response.merge!(
            acknowledged_at: call.acknowledged_at&.iso8601,
            completed_at: call.completed_at&.iso8601,
            time_in_service: call.time_in_service.round,
            assigned_staff: call.assigned_staff ? {
              id: call.assigned_staff.id,
              name: call.assigned_staff.user.name,
              role: call.assigned_staff.role
            } : nil
          )
        end
        
        response
      end
    end
  end
end

