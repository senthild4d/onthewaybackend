# frozen_string_literal: true

module Api
  module V1
    # Country-level support team moderation.
    # Support users can remove events and posts only in their assigned countries.
    class SupportModerationController < ApplicationController
      before_action :require_authentication!
      before_action :require_support_role!
      before_action :set_event, only: [:remove_event]
      before_action :set_event_post, only: [:remove_post]

      # POST /api/v1/support/events/:id/remove
      def remove_event
        unless can_moderate?(@event.event_country)
          api_error(message: 'You can only moderate events in your assigned country', status: :forbidden)
          return
        end

        @event.block!(current_user, scope: 'all', reason: params[:reason])
        if @event.save
          api_success(
            data: { event_id: @event.id, blocked_at: @event.blocked_at&.iso8601 },
            message: 'Event removed successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event.errors.full_messages)
        end
      end

      # POST /api/v1/support/events/:event_id/posts/:id/remove
      def remove_post
        event_country = @event_post.event.event_country
        unless can_moderate?(event_country)
          api_error(message: 'You can only moderate posts in your assigned country', status: :forbidden)
          return
        end

        if @event_post.soft_delete
          api_success(
            data: { post_id: @event_post.id },
            message: 'Post removed successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to remove post', status: :unprocessable_entity)
        end
      end

      private

      def require_support_role!
        unless current_user.role_support? || current_user.role_admin?
          api_error(message: 'Only support team or admin can perform this action', status: :forbidden)
        end
      end

      # Admin can moderate any country; support only their assigned countries
      def can_moderate?(country_code)
        return true if current_user.role_admin?
        current_user.support_manages_country?(country_code)
      end

      def set_event
        @event = Event.find_by(id: params[:id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
        end
      end

      def set_event_post
        @event_post = EventPost.find_by(id: params[:id], event_id: params[:event_id])
        unless @event_post
          api_error(message: 'Post not found', status: :not_found)
        end
      end
    end
  end
end
