module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :require_authentication!
      before_action :set_notification, only: [:show, :mark_read, :destroy]

      # GET /api/v1/notifications
      def index
        scope = current_user.notifications.recent
        scope = scope.where(read: false) if params[:unread_only].to_s == 'true'
        scope = scope.of_type(params[:type]) if params[:type].present?

        page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        notifications = scope.limit(per_page).offset(offset)

        api_success(
          data: {
            notifications: notifications.map { |n| notification_response(n) },
            unread_count: current_user.notifications.unread.count,
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: total_pages,
              has_next_page: page < total_pages,
              has_prev_page: page > 1
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        api_success(
          data: { unread_count: current_user.notifications.unread.count },
          status: :ok
        )
      end

      # GET /api/v1/notifications/:id
      def show
        @notification.mark_read! unless @notification.read?
        NotificationService.broadcast_to_user(current_user, action: 'read', notification: @notification.reload)
        api_success(data: { notification: notification_response(@notification.reload) }, status: :ok)
      end

      # PATCH /api/v1/notifications/:id/mark_read
      def mark_read
        @notification.mark_read!
        NotificationService.broadcast_to_user(current_user, action: 'read', notification: @notification.reload)
        api_success(
          data: { notification: notification_response(@notification.reload) },
          message: 'Notification marked as read',
          status: :ok
        )
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        count = current_user.notifications.unread.count
        Notification.mark_all_read_for(current_user)
        NotificationService.broadcast_to_user(
          current_user,
          action: 'all_read',
          extra: { marked_count: count }
        )
        api_success(
          data: { marked_count: count },
          message: 'All notifications marked as read',
          status: :ok
        )
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        notification_payload = notification_response(@notification)
        @notification.destroy
        NotificationService.broadcast_to_user(
          current_user,
          action: 'deleted',
          extra: { notification: notification_payload }
        )
        api_success(message: 'Notification deleted', data: { id: @notification.id }, status: :ok)
      end

      # POST /api/v1/notifications/test
      # Send a test push notification to the current user's devices
      def test
        title = params[:title].presence || 'Test Notification'
        body = params[:body].presence || 'This is a test notification'

        notification = NotificationService.send_to_user(
          current_user,
          title: title,
          body: body,
          notification_type: 'system',
          data: { test: true }
        )

        if notification
          api_success(
            data: { notification: notification_response(notification) },
            message: 'Test notification sent',
            status: :ok
          )
        else
          api_error(message: 'Failed to send test notification', status: :unprocessable_entity)
        end
      end

      private

      def set_notification
        @notification = current_user.notifications.find_by(id: params[:id])
        unless @notification
          api_error(message: 'Notification not found', status: :not_found)
          return
        end
      end

      def notification_response(n)
        {
          id: n.id,
          notification_type: n.notification_type,
          title: n.title,
          body: n.body,
          data: n.data || {},
          related_type: n.related_type,
          related_id: n.related_id,
          read: n.read,
          read_at: n.read_at&.iso8601,
          created_at: n.created_at.iso8601
        }
      end
    end
  end
end
