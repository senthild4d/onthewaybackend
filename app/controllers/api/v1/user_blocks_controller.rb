module Api
  module V1
    class UserBlocksController < ApplicationController
      before_action :require_authentication!
      before_action :set_user, only: [:block, :unblock, :check_block]
      
      # POST /api/v1/users/:user_id/block
      def block
        if @user == current_user
          api_error(message: 'You cannot block yourself', status: :bad_request)
          return
        end
        
        if current_user.blocked?(@user)
          api_error(message: 'You have already blocked this user', status: :bad_request)
          return
        end
        
        if current_user.block!(@user)
          api_success(
            data: {
              blocker: user_basic_response(current_user),
              blocked: user_basic_response(@user),
              is_blocked: true
            },
            message: 'User blocked successfully',
            status: :created
          )
        else
          api_error(message: 'Failed to block user', status: :internal_server_error)
        end
      rescue => e
        Rails.logger.error "Block User Error: #{e.message}"
        api_error(message: 'Failed to block user', status: :internal_server_error)
      end
      
      # DELETE /api/v1/users/:user_id/block
      def unblock
        unless current_user.blocked?(@user)
          api_error(message: 'You have not blocked this user', status: :bad_request)
          return
        end
        
        if current_user.unblock!(@user)
          api_success(
            data: {
              blocker: user_basic_response(current_user),
              blocked: user_basic_response(@user),
              is_blocked: false
            },
            message: 'User unblocked successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to unblock user', status: :internal_server_error)
        end
      rescue => e
        Rails.logger.error "Unblock User Error: #{e.message}"
        api_error(message: 'Failed to unblock user', status: :internal_server_error)
      end
      
      # GET /api/v1/users/:user_id/block/check
      def check_block
        api_success(
          data: {
            user: user_basic_response(@user),
            is_blocked: current_user.blocked?(@user),
            is_blocked_by: current_user.blocked_by?(@user)
          },
          status: :ok
        )
      end
      
      # GET /api/v1/users/me/blocked
      def my_blocked
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        
        blocked_users = current_user.blocked_user_records
        total_count = blocked_users.count
        blocked_users = blocked_users.limit(limit).offset(offset)
        
        api_success(
          data: {
            blocked_users: blocked_users.map { |user| user_basic_response(user) },
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
        {
          id: user.id,
          name: user.name,
          username: user.username,
          role: user.role,
          avatar_url: user.respond_to?(:avatar_url) && user.avatar_url.present? ? user.avatar_url : default_avatar_url
        }
      end
    end
  end
end

