module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :require_authentication!
      before_action :set_notification, only: [:show, :mark_read, :mark_unread, :destroy]
      
      # GET /api/v1/notifications
      def index
        notifications = current_user.notifications.recent
        
        # Filter by read status
        if params[:read].present?
          notifications = params[:read] == 'true' ? notifications.read : notifications.unread
        end
        
        # Filter by type (backend snake_case or Flutter camelCase)
        if params[:type].present?
          backend_types = Notification.backend_types_for_flutter_type(params[:type])
          notifications = backend_types.one? ? notifications.by_type(backend_types.first) : notifications.where(notification_type: backend_types)
        end
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = notifications.count
        
        notifications = notifications.limit(limit).offset(offset)
        
        api_success(
          data: {
            notifications: notifications.map { |n| notification_response(n) },
            unread_count: current_user.unread_notifications_count,
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
      
      # GET /api/v1/notifications/:id
      def show
        api_success(
          data: { notification: notification_response(@notification) },
          status: :ok
        )
      end
      
      # GET /api/v1/notifications/unread_count
      def unread_count
        api_success(
          data: {
            unread_count: current_user.unread_notifications_count
          },
          status: :ok
        )
      end
      
      # POST /api/v1/notifications/:id/read
      def mark_read
        @notification.mark_as_read!
        api_success(
          data: { notification: notification_response(@notification) },
          message: 'Notification marked as read',
          status: :ok
        )
      end
      
      # POST /api/v1/notifications/:id/unread
      def mark_unread
        @notification.mark_as_unread!
        api_success(
          data: { notification: notification_response(@notification) },
          message: 'Notification marked as unread',
          status: :ok
        )
      end
      
      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        count = current_user.notifications.unread.update_all(read: true, read_at: Time.current)
        api_success(
          data: { marked_count: count },
          message: 'All notifications marked as read',
          status: :ok
        )
      end
      
      # DELETE /api/v1/notifications/:id
      def destroy
        if @notification.destroy
          api_success(message: 'Notification deleted successfully', status: :ok)
        else
          api_error(message: 'Failed to delete notification', status: :internal_server_error)
        end
      end
      
      # DELETE /api/v1/notifications/clear_all
      def clear_all
        count = current_user.notifications.count
        current_user.notifications.destroy_all
        api_success(
          data: { deleted_count: count },
          message: 'All notifications cleared',
          status: :ok
        )
      end
      
      private
      
      def set_notification
        @notification = current_user.notifications.find_by(id: params[:id])
        unless @notification
          api_error(message: 'Notification not found', status: :not_found)
          return
        end
      end
      
      def notification_response(notification)
        meta = notification.metadata_hash.with_indifferent_access
        # Flutter NotificationType enum: followRequest, eventStart, startedFollowing, eventCancelled, reelLike
        type = notification.respond_to?(:flutter_type) ? notification.flutter_type : notification.notification_type

        payload = {
          id: notification.id,
          type: type,
          notification_type: notification.notification_type,
          title: notification.title,
          message: notification.message,
          read: notification.read,
          read_at: notification.read_at&.iso8601,
          created_at: notification.created_at.iso8601,
          timestamp: notification.created_at.iso8601,
          metadata: meta
        }

        # Sender (for follow request, started following, reel like, follow_request_accepted)
        sender_id = meta['sender_id'] || meta['requester_id'] || meta['follower_id'] || meta['user_id'] || meta['liker_id'] || meta['requested_id']
        if sender_id.present?
          sender = User.find_by(id: sender_id)
          sender_name = meta['requester_name'] || meta['follower_name'] || meta['requested_name']
          sender_username = meta['requester_username'] || meta['follower_username'] || meta['requested_username']
          payload[:sender] = sender ? sender_basic(sender) : { id: sender_id, name: sender_name, username: sender_username }
          # Ensure message has a display name (fix " wants to follow you", " started following you", etc.)
          payload[:message] = notification_display_message(notification, payload[:sender]) if sender_name_missing_in_message?(payload[:message])
        end

        # Event (for eventStart, eventCancelled)
        event_id = meta['event_id']
        if event_id.present?
          event = Event.find_by(id: event_id)
          payload[:event] = event ? { id: event.id, title: event.title, starts_at: event.starts_at&.iso8601, status: event.status } : { id: event_id }
        end

        # Reel (for reelLike)
        reel_id = meta['reel_id']
        payload[:reel_id] = reel_id if reel_id.present?

        # Follow request (for Accept/Decline actions) - get actual status from database
        if notification.notification_type == 'follow_request' && meta['follow_request_id'].present?
          follow_request = FollowRequest.find_by(id: meta['follow_request_id'])
          if follow_request
            # Check if this is a "follow back" scenario:
            # If accepted, check if requested user was already following requester OR had a follow request to requester
            is_follow_back = false
            reverse_follow_request_status = nil
            if follow_request.accepted?
              # Check if reverse Follow relationship exists (requested was already following requester)
              reverse_follow = Follow.find_by(follower_id: follow_request.requested_id, following_id: follow_request.requester_id)
              reverse_follow_exists = reverse_follow.present? && reverse_follow.created_at < follow_request.created_at
              
              # Check if reverse FollowRequest exists (requested had sent a request to requester before this request)
              reverse_follow_request = FollowRequest.where(
                requester_id: follow_request.requested_id,
                requested_id: follow_request.requester_id
              ).where('created_at < ?', follow_request.created_at)
               .where(status: ['pending', 'accepted'])
               .order(created_at: :desc)
               .first
              
              # It's a follow back if either reverse follow or reverse follow request existed before this request
              is_follow_back = reverse_follow_exists || reverse_follow_request.present?
              
              # Include reverse follow request status if it exists
              if reverse_follow_request.present?
                reverse_follow_request_status = reverse_follow_request.status
              elsif reverse_follow_exists
                # If reverse follow exists, it means they're already following (equivalent to "accepted")
                reverse_follow_request_status = 'accepted'
              end
            end
            
            follow_request_payload = { 
              id: follow_request.id, 
              status: follow_request.status,
              is_follow_back: is_follow_back
            }
            # Include reverse follow request status when it's a follow back
            follow_request_payload[:reverse_follow_request_status] = reverse_follow_request_status if reverse_follow_request_status.present?
            payload[:follow_request] = follow_request_payload
          else
            # Follow request was deleted, but notification still references it
            payload[:follow_request] = { id: meta['follow_request_id'], status: 'deleted', is_follow_back: false }
          end
        end

        payload
      end

      def sender_basic(user)
        {
          id: user.id,
          name: user.name,
          username: user.username,
          avatar_url: user.respond_to?(:avatar_url) && user.avatar_url.present? ? user.avatar_url : default_avatar_url
        }
      end

      def sender_name_missing_in_message?(message)
        s = message.to_s.strip
        s.start_with?(' wants to ') || s.start_with?(' started ') || s.start_with?(' accepted ')
      end

      # Build display message when stored message is missing sender name (e.g. " wants to follow you")
      def notification_display_message(notification, sender)
        name = sender[:name].presence || sender[:username].presence || 'Someone'
        case notification.notification_type
        when 'follow_request' then "#{name} wants to follow you"
        when 'follow' then "#{name} started following you"
        when 'follow_request_accepted' then "#{name} accepted your follow request"
        else notification.message
        end
      end
    end
  end
end

