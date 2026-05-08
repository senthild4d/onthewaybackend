module Api
  module V1
    class FollowsController < ApplicationController
      before_action :require_authentication!
      before_action :set_user, only: [:follow, :unfollow, :check_follow]
      
      # POST /api/v1/users/:user_id/follow
      # Creates a follow REQUEST (requires acceptance)
      def follow
        if @user == current_user
          Rails.logger.info "[FollowsController] Rejected: user #{current_user.id} tried to follow themselves"
          api_error(message: 'You cannot follow yourself', status: :bad_request)
          return
        end
        
        if current_user.following?(@user)
          Rails.logger.info "[FollowsController] Rejected: user #{current_user.id} already following #{@user.id}"
          api_error(message: 'You are already following this user', status: :bad_request)
          return
        end

        if current_user.has_pending_request_to?(@user)
          Rails.logger.info "[FollowsController] Rejected: user #{current_user.id} already has pending request to #{@user.id}"
          api_error(message: 'You already have a pending follow request to this user', status: :bad_request)
          return
        end
        
        begin
          request = FollowRequest.create!(requester: current_user, requested: @user)
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[FollowsController] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          raise
        rescue ActiveRecord::RecordNotUnique => e
          Rails.logger.error "[FollowsController] Duplicate pending request detected: #{e.message}"
          api_error(message: 'You already have a pending follow request to this user', status: :bad_request)
          return
        end
        
        # Create notification for the requested user (prevent duplicates)
        notification = nil
        begin
          recent_notification = Notification.where(
            user_id: @user.id,
            notification_type: 'follow_request'
          ).where('metadata->>? = ?', 'follow_request_id', request.id.to_s)
           .where('created_at > ?', 1.minute.ago)
           .exists?
          
          unless recent_notification
            requester_display = current_user.name.presence || current_user.username.presence || 'Someone'
            notification = Notification.create!(
              user: @user,
              notification_type: 'follow_request',
              title: 'New Follow Request',
              message: "#{requester_display} wants to follow you",
              metadata: {
                requester_id: current_user.id,
                requester_name: current_user.name,
                requester_username: current_user.username,
                follow_request_id: request.id
              }
            )
          end
        rescue => e
          Rails.logger.error "Failed to create follow request notification: #{e.message}"
          notification = nil
        end
        
        # Triggered by requester's action; send FCM to the requested user (recipient of the follow request).
        if notification && should_send_push_notification?(@user, 'follow_request')
          send_follow_request_push_notification(@user, notification, current_user)
        end
        
        api_success(
          data: {
            follow_request: {
              id: request.id,
              requester: user_basic_response(current_user),
              requested: user_basic_response(@user),
              status: request.status,
              created_at: request.created_at.iso8601
            },
            is_following: false,
            has_pending_request: true
          },
          message: 'Follow request sent. Waiting for acceptance.',
          status: :created
        )
      rescue ActiveRecord::RecordInvalid => e
        api_error(message: e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue => e
        Rails.logger.error "Follow Request Error: #{e.message}"
        api_error(message: 'Failed to send follow request', status: :internal_server_error)
      end
      
      # DELETE /api/v1/users/:user_id/follow
      def unfollow
        unless current_user.following?(@user)
          api_error(message: 'You are not following this user', status: :bad_request)
          return
        end
        
        if current_user.unfollow!(@user)
          api_success(
            data: {
              follower: user_basic_response(current_user),
              following: user_basic_response(@user),
              is_following: false
            },
            message: 'Successfully unfollowed user',
            status: :ok
          )
        else
          api_error(message: 'Failed to unfollow user', status: :internal_server_error)
        end
      rescue => e
        Rails.logger.error "Unfollow Error: #{e.message}"
        api_error(message: 'Failed to unfollow user', status: :internal_server_error)
      end
      
      # GET /api/v1/users/:user_id/follow/check
      def check_follow
        pending_request_to = current_user.follow_requests_sent.pending.find_by(requested_id: @user.id)
        pending_request_from = current_user.follow_requests_received.pending.find_by(requester_id: @user.id)
        
        api_success(
          data: {
            user: user_basic_response(@user),
            is_following: current_user.following?(@user),
            is_followed_by: current_user.followed_by?(@user),
            has_pending_request_to: pending_request_to.present?,
            has_pending_request_from: pending_request_from.present?,
            pending_request_id: pending_request_from&.id
          },
          status: :ok
        )
      end
      
      # GET /api/v1/users/me/following
      def following
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        
        following_users = current_user.following
        
        # Filter by role if provided
        following_users = following_users.where(role: params[:role]) if params[:role].present?
        
        total_count = following_users.count
        following_users = following_users.limit(limit).offset(offset)
        
        api_success(
          data: {
            following: following_users.map do |user|
              response = user_basic_response(user)
              response[:is_following] = current_user.following?(user) # Should always be true, but included for consistency
              response
            end,
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
      
      # GET /api/v1/users/me/followers
      def followers
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        
        followers_users = current_user.followers
        
        # Filter by role if provided
        followers_users = followers_users.where(role: params[:role]) if params[:role].present?
        
        total_count = followers_users.count
        followers_users = followers_users.limit(limit).offset(offset)
        
        api_success(
          data: {
            followers: followers_users.map do |user|
              response = user_basic_response(user)
              response[:is_following] = current_user.following?(user) # Whether current_user is following this follower
              response
            end,
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
      
      private
      
      def set_user
        @user = User.find_by(id: params[:user_id])
        unless @user
          api_error(message: 'User not found', status: :not_found)
          return
        end
      end
      
      def user_basic_response(user)
        avatar_url = if user.respond_to?(:avatar_url) && user.avatar_url.present?
                      # Convert relative path to full URL if needed
                      if user.avatar_url.start_with?('http')
                        user.avatar_url
                      else
                        "#{request.base_url}#{user.avatar_url}"
                      end
                    else
                      default_avatar_url
                    end
        
        {
          id: user.id,
          name: user.name,
          username: user.username,
          role: user.role,
          avatar_url: avatar_url
        }
      end
      
      # Check if user has push notifications enabled for follow requests
      def should_send_push_notification?(user, notification_type)
        return true unless user.preferences.is_a?(Hash)
        
        prefs = user.preferences['push_notification_settings']
        return true unless prefs.is_a?(Hash)
        
        # Follow requests fall under interactions -> new_followers (or we can add follow_requests later)
        interactions = prefs['interactions']
        return true unless interactions.is_a?(Hash)
        
        # Default to true if not explicitly disabled
        interactions['new_followers'] != false && interactions['follow_requests'] != false
      end
      
      # Send FCM push notification for follow request
      def send_follow_request_push_notification(user, notification, requester)
        return unless FcmService.configured?
        
        meta = notification.metadata_hash
        flutter_type = notification.respond_to?(:flutter_type) ? notification.flutter_type : 'followRequest'
        body = follow_request_push_body(notification, requester)
        
        FcmService.send_to_user(
          user,
          title: notification.title,
          body: body,
          data: {
            notification_id: notification.id.to_s,
            notification_type: notification.notification_type,
            type: flutter_type,
            follow_request_id: meta['follow_request_id'].to_s,
            requester_id: meta['requester_id'].to_s,
            requester_name: (meta['requester_name'].presence || meta['requester_username'].presence || 'Someone').to_s,
            requester_username: (meta['requester_username'].presence || '').to_s
          }
        )
      rescue => e
        Rails.logger.error "Failed to send follow request push notification: #{e.message}"
        # Don't fail the request if push notification fails
      end

      # Ensure FCM body always has a display name (never " wants to follow you")
      def follow_request_push_body(notification, requester)
        msg = notification.message.to_s
        return msg unless msg.strip.start_with?(' wants to ')
        name = requester.name.presence || requester.username.presence || 'Someone'
        "#{name} wants to follow you"
      end
    end
  end
end

