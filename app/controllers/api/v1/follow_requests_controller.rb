module Api
  module V1
    class FollowRequestsController < ApplicationController
      before_action :require_authentication!
      before_action :set_follow_request, only: [:accept, :reject, :cancel]

      # GET /api/v1/users/me/follow_requests/received
      # List follow requests received (pending requests to accept/reject)
      def received
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0

        requests = current_user.follow_requests_received.pending
                                .includes(:requester)
                                .order(created_at: :desc)

        total_count = requests.count
        requests = requests.limit(limit).offset(offset)

        api_success(
          data: {
            follow_requests: requests.map { |req| follow_request_response(req) },
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

      # GET /api/v1/users/me/follow_requests/sent
      # List follow requests sent (pending requests waiting for response)
      def sent
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0

        requests = current_user.follow_requests_sent.pending
                                .includes(:requested)
                                .order(created_at: :desc)

        total_count = requests.count
        requests = requests.limit(limit).offset(offset)

        api_success(
          data: {
            follow_requests: requests.map { |req| follow_request_response(req) },
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

      # POST /api/v1/users/me/follow_requests/:id/accept
      # Accept a follow request (creates the Follow relationship)
      def accept
        unless @follow_request.requested_id == current_user.id
          api_error(message: 'You can only accept requests sent to you', status: :forbidden)
          return
        end

        unless @follow_request.pending?
          api_error(message: 'This follow request is no longer pending', status: :bad_request)
          return
        end

        if @follow_request.accept!
          api_success(
            data: {
              follow_request: follow_request_response(@follow_request.reload),
              follow: {
                follower: user_basic_response(@follow_request.requester),
                following: user_basic_response(@follow_request.requested),
                is_following: true
              }
            },
            message: 'Follow request accepted',
            status: :ok
          )
        else
          api_error(message: 'Failed to accept follow request', status: :internal_server_error)
        end
      end

      # POST /api/v1/users/me/follow_requests/:id/reject
      # Reject a follow request
      def reject
        unless @follow_request.requested_id == current_user.id
          api_error(message: 'You can only reject requests sent to you', status: :forbidden)
          return
        end

        unless @follow_request.pending?
          api_error(message: 'This follow request is no longer pending', status: :bad_request)
          return
        end

        if @follow_request.reject!
          api_success(
            data: {
              follow_request: follow_request_response(@follow_request.reload)
            },
            message: 'Follow request rejected',
            status: :ok
          )
        else
          api_error(message: 'Failed to reject follow request', status: :internal_server_error)
        end
      end

      # POST /api/v1/users/me/follow_requests/:id/cancel
      # Cancel a follow request you sent
      def cancel
        unless @follow_request.requester_id == current_user.id
          api_error(message: 'You can only cancel requests you sent', status: :forbidden)
          return
        end

        unless @follow_request.pending?
          api_error(message: 'This follow request is no longer pending', status: :bad_request)
          return
        end

        if @follow_request.cancel!
          api_success(
            data: {
              follow_request: follow_request_response(@follow_request.reload)
            },
            message: 'Follow request cancelled',
            status: :ok
          )
        else
          api_error(message: 'Failed to cancel follow request', status: :internal_server_error)
        end
      end

      private

      def set_follow_request
        @follow_request = FollowRequest.find_by(id: params[:id])
        unless @follow_request
          api_error(message: 'Follow request not found', status: :not_found)
          return
        end
      end

      def follow_request_response(request)
        {
          id: request.id,
          requester: user_basic_response(request.requester),
          requested: user_basic_response(request.requested),
          status: request.status,
          created_at: request.created_at.iso8601,
          responded_at: request.responded_at&.iso8601
        }
      end

      def user_basic_response(user)
        avatar_url = if user.respond_to?(:avatar_url) && user.avatar_url.present?
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
    end
  end
end
