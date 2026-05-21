module Api
  module V1
    class PropertyViewingsController < ApplicationController
      before_action :require_authentication!
      before_action :set_property, only: [:create]
      before_action :set_viewing, only: [:show, :update, :cancel]
      before_action :authorize_admin!, only: [:index, :update]

      # GET /api/v1/viewings (admin only)
      def index
        scope = PropertyViewing.includes(:property, :user).recent
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(property_id: params[:property_id]) if params[:property_id].present?
        scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

        limit = [params[:limit]&.to_i || 50, 200].min
        api_success(data: { viewings: scope.limit(limit).map { |v| viewing_response(v) } }, status: :ok)
      end

      # GET /api/v1/viewings/my
      def my
        scope = current_user.property_viewings.includes(:property).recent
        api_success(data: { viewings: scope.map { |v| viewing_response(v) } }, status: :ok)
      end

      # GET /api/v1/properties/:property_id/viewings (owner/admin)
      def property_viewings
        property = Property.find_by(id: params[:property_id])
        unless property
          api_error(message: 'Property not found', status: :not_found)
          return
        end

        unless current_user.admin? || (current_user.role_owner? && property.owner_id == current_user.id)
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        scope = property.viewings.includes(:user).recent
        api_success(data: { viewings: scope.map { |v| viewing_response(v) } }, status: :ok)
      end

      # POST /api/v1/properties/:property_id/viewings
      def create
        unless @property.approval_status_approved? && @property.listing_status_active?
          api_error(message: 'Viewing can only be requested for active approved listings', status: :bad_request)
          return
        end

        viewing = PropertyViewing.new(viewing_params)
        viewing.user = current_user
        viewing.property = @property

        if viewing.save
          notify_owner_of_request(viewing)
          PropertyRealtimeService.viewing_updated(viewing, action: 'requested', actor: current_user)
          api_success(data: { viewing: viewing_response(viewing) }, message: 'Viewing requested', status: :created)
        else
          api_validation_error(errors: viewing.errors.full_messages)
        end
      end

      # GET /api/v1/viewings/:id
      def show
        api_success(data: { viewing: viewing_response(@viewing, detailed: true) }, status: :ok)
      end

      # PATCH /api/v1/viewings/:id (admin only)
      def update
        previous_status = @viewing.status
        if @viewing.update(viewing_update_params.merge(handled_by_id: current_user.id, handled_at: Time.current))
          notify_viewing_status_change(@viewing, previous_status) if previous_status != @viewing.status
          PropertyRealtimeService.viewing_updated(@viewing.reload, action: 'updated', actor: current_user)
          api_success(data: { viewing: viewing_response(@viewing.reload, detailed: true) }, message: 'Viewing updated', status: :ok)
        else
          api_validation_error(errors: @viewing.errors.full_messages)
        end
      end

      # POST /api/v1/viewings/:id/cancel (user can cancel own)
      def cancel
        unless @viewing.user_id == current_user.id || current_user.admin?
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end

        @viewing.update!(status: 'cancelled')
        notify_viewing_status_change(@viewing, 'cancelled_by_user')
        PropertyRealtimeService.viewing_updated(@viewing.reload, action: 'cancelled', actor: current_user)
        api_success(data: { viewing: viewing_response(@viewing.reload, detailed: true) }, message: 'Viewing cancelled', status: :ok)
      end

      private

      def notify_owner_of_request(viewing)
        return unless viewing.property&.owner
        return if viewing.property.owner_id == viewing.user_id

        NotificationService.send_to_user(
          viewing.property.owner,
          title: 'New Viewing Request',
          body: "#{viewing.user&.name || 'A user'} requested a viewing for \"#{viewing.property.title}\"",
          notification_type: 'viewing_requested',
          data: { viewing_id: viewing.id.to_s, property_id: viewing.property_id.to_s },
          related: viewing
        )
      rescue => e
        Rails.logger.error "Failed to send notification: #{e.message}"
      end

      def notify_viewing_status_change(viewing, previous_status)
        type_map = {
          'confirmed' => ['viewing_confirmed', 'Viewing Confirmed'],
          'cancelled' => ['viewing_cancelled', 'Viewing Cancelled'],
          'completed' => ['viewing_completed', 'Viewing Completed']
        }
        info = type_map[viewing.status]
        return unless info

        notification_type, title = info
        body = "Your viewing for \"#{viewing.property&.title}\" is now #{viewing.status}."

        NotificationService.send_to_user(
          viewing.user,
          title: title,
          body: body,
          notification_type: notification_type,
          data: { viewing_id: viewing.id.to_s, property_id: viewing.property_id.to_s },
          related: viewing
        )
      rescue => e
        Rails.logger.error "Failed to send notification: #{e.message}"
      end

      def authorize_admin!
        return if current_user&.admin?
        api_error(message: 'Admin required', status: :forbidden)
      end

      def set_property
        @property = Property.find_by(id: params[:property_id])
        unless @property
          api_error(message: 'Property not found', status: :not_found)
        end
      end

      def set_viewing
        @viewing = PropertyViewing.find_by(id: params[:id])
        unless @viewing
          api_error(message: 'Viewing not found', status: :not_found)
          return
        end

        # Access: admin OR owner of property OR user who requested it
        return if current_user.admin?
        return if @viewing.user_id == current_user.id
        return if current_user.role_owner? && @viewing.property&.owner_id == current_user.id

        api_error(message: 'Unauthorized', status: :forbidden)
      end

      def viewing_params
        params.require(:viewing).permit(:requested_for, :message, :contact_phone, :contact_email)
      end

      def viewing_update_params
        params.require(:viewing).permit(:status, :admin_notes, :requested_for)
      end

      def viewing_response(v, detailed: false)
        data = {
          id: v.id,
          property_id: v.property_id,
          user_id: v.user_id,
          status: v.status,
          requested_for: v.requested_for&.iso8601,
          message: v.message,
          contact_phone: v.contact_phone,
          contact_email: v.contact_email,
          handled_by_id: v.handled_by_id,
          handled_at: v.handled_at&.iso8601,
          admin_notes: v.admin_notes,
          created_at: v.created_at&.iso8601
        }

        if detailed
          data[:property] = v.property ? { id: v.property.id, title: v.property.title } : nil
          data[:user] = v.user ? { id: v.user.id, name: v.user.name, phone: v.user.phone, email: v.user.email } : nil
        end

        data
      end
    end
  end
end

