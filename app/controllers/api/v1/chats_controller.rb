module Api
  module V1
    class ChatsController < ApplicationController
      include PrChatUsersHelpers
      include ChatUserPayload

      before_action :require_authentication!
      before_action :set_chat, only: [:show, :block, :unblock, :mute, :unmute, :pin, :unpin, :archive, :unarchive, :report]

      # GET /api/v1/chats
      def index
        chats = Chat.for_user(current_user)
                    .active(current_user)
                    .includes(:messages, user1: :venue_pr_partnerships, user2: :venue_pr_partnerships)
        
        # Filter by pinned
        if params[:pinned] == 'true'
          chats = chats.pinned(current_user)
        end
        
        # Sort: pinned first, then by last_message_at
        memberships_data = {}
        chats.each do |chat|
          pinned = chat.pinned_by?(current_user)
          memberships_data[chat.id] = { pinned: pinned }
        end
        
        all_chats = chats.to_a.sort_by do |chat|
          [
            memberships_data[chat.id][:pinned] ? 0 : 1, # Pinned first
            -(chat.last_message_at || chat.created_at).to_i # Most recent first
          ]
        end
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = all_chats.count
        chats_list = all_chats[offset, limit] || []
        
        api_success(
          data: {
            chats: chats_list.map { |chat| chat_response(chat) },
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

      # GET /api/v1/chats/:id
      def show
        api_success(
          data: {
            chat: chat_response(@chat, include_details: true)
          },
          status: :ok
        )
      end

      # POST /api/v1/chats
      def create
        other_user = resolve_other_user_for_create
        return unless other_user

        booking = nil
        booking_id = params[:booking_id].presence
        if booking_id
          booking = Booking.includes(:event).find_by(id: booking_id)
          unless booking
            api_error(message: 'Booking not found', status: :not_found)
            return
          end

          # Allow booking-scoped chat only to booking user or venue-side users.
          unless booking.user_id == current_user.id || can_access_event_pr_chat_users?(booking.event)
            api_error(message: 'Unauthorized', status: :forbidden)
            return
          end
        end

        # Check if chat already exists (check both combinations)
        user1_id, user2_id = [current_user.id, other_user.id].sort
        chat = Chat.find_by(user1_id: user1_id, user2_id: user2_id, booking_id: booking&.id)
        
        if chat.nil?
          # Create new chat (ensure user1_id < user2_id for consistency)
          chat = Chat.create!(
            user1_id: user1_id,
            user2_id: user2_id,
            booking_id: booking&.id
          )
        end

        api_success(
          data: { chat: chat_response(chat, include_details: true) },
          message: 'Chat created successfully',
          status: :created
        )
      end

      # POST /api/v1/chats/:id/block
      def block
        @chat.block!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'User blocked successfully',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/unblock
      def unblock
        @chat.unblock!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'User unblocked successfully',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/report
      def report
        other_user = @chat.other_user(current_user)
        reason = params[:reason]
        description = params[:description]

        unless reason
          api_error(message: 'Report reason is required', status: :bad_request)
          return
        end

        unless UserReport::REASONS.include?(reason)
          api_error(message: "Invalid reason. Must be one of: #{UserReport::REASONS.join(', ')}", status: :bad_request)
          return
        end

        report = UserReport.create!(
          reporter: current_user,
          reported: other_user,
          reason: reason,
          description: description
        )

        api_success(
          data: { report: report_response(report) },
          message: 'User reported successfully. Our team will review it shortly.',
          status: :created
        )
      end

      # POST /api/v1/chats/:id/mute
      def mute
        @chat.mute!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'Chat muted',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/unmute
      def unmute
        @chat.unmute!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'Chat unmuted',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/pin
      def pin
        @chat.pin!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'Chat pinned',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/unpin
      def unpin
        @chat.unpin!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'Chat unpinned',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/archive
      def archive
        @chat.archive!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'Chat archived',
          status: :ok
        )
      end

      # POST /api/v1/chats/:id/unarchive
      def unarchive
        @chat.unarchive!(current_user)
        
        api_success(
          data: { chat: chat_response(@chat) },
          message: 'Chat unarchived',
          status: :ok
        )
      end

      private

      def set_chat
        @chat = Chat.for_user(current_user)
                    .includes(user1: :venue_pr_partnerships, user2: :venue_pr_partnerships)
                    .find_by(id: params[:id])
        unless @chat
          api_error(message: 'Chat not found', status: :not_found)
        end
      end

      def chat_response(chat, include_details: false)
        other_user = chat.other_user(current_user)
        last_message = chat.messages.not_deleted.recent.first
        
        response = {
          id: chat.id,
          booking_id: chat.booking_id&.to_s,
          other_user: chat_user_json(other_user),
          is_blocked: chat.blocked_by?(current_user),
          is_muted: chat.muted_by?(current_user),
          is_pinned: chat.pinned_by?(current_user),
          is_archived: chat.archived_by?(current_user),
          unread_count: chat.unread_count_for(current_user),
          last_message: last_message ? {
            id: last_message.id,
            content: last_message.content,
            message_type: last_message.message_type,
            sender_id: last_message.sender_id,
            created_at: last_message.created_at.iso8601
          } : nil,
          last_message_at: chat.last_message_at&.iso8601,
          created_at: chat.created_at.iso8601,
          updated_at: chat.updated_at.iso8601
        }

        if include_details
          response[:messages_count] = chat.messages.count
        end

        response
      end

      def report_response(report)
        {
          id: report.id,
          reported_user: {
            id: report.reported.id,
            name: report.reported.name,
            username: report.reported.username
          },
          reason: report.reason,
          description: report.description,
          status: report.status,
          created_at: report.created_at.iso8601
        }
      end

      def resolve_other_user_for_create
        user_id = params[:user_id].presence
        return User.find_by(id: user_id).tap { |u| return u if u } if user_id

        # Auto-assign PR contact by event_id (preferred) or venue_id.
        event_id = params[:event_id].presence
        venue_id = params[:venue_id].presence

        if event_id
          event = Event.find_by(id: event_id)
          unless event
            api_error(message: 'Event not found', status: :not_found)
            return nil
          end

          unless can_access_event_pr_chat_users?(event)
            api_error(message: 'You do not have access to PR contacts for this event', status: :forbidden)
            return nil
          end

          venue_id ||= event.venue_id
        end

        if venue_id
          venue = Venue.find_by(id: venue_id)
          unless venue
            api_error(message: 'Venue not found', status: :not_found)
            return nil
          end

          partnerships = venue.venue_pr_partnerships
                             .active
                             .includes(:user)
                             .order(Arel.sql("CASE venue_pr_partnerships.role WHEN 'master_pr' THEN 0 ELSE 1 END"))
                             .order(:created_at)
          pr_user = partnerships.map(&:user).compact.first
          unless pr_user
            api_error(message: 'No active PR users for this venue', status: :unprocessable_entity)
            return nil
          end

          return pr_user
        end

        api_error(message: 'user_id is required (or provide event_id/venue_id to auto-assign a PR user)', status: :unprocessable_entity)
        nil
      end
    end
  end
end

