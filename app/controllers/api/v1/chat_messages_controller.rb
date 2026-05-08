module Api
  module V1
    class ChatMessagesController < ApplicationController
      include ChatUserPayload

      before_action :require_authentication!
      before_action :set_chat
      before_action :check_chat_access
      before_action :set_message, only: [:show, :destroy, :edit, :forward]

      # GET /api/v1/chats/:chat_id/messages
      def index
        messages = @chat.messages.not_deleted.includes(:forwarded_from, sender: :venue_pr_partnerships, reply_to: :sender)
        
        # Filter by message type
        messages = messages.where(message_type: params[:message_type]) if params[:message_type].present?
        
        # Limit results
        limit = [params[:limit]&.to_i || 50, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = messages.count
        
        # Order by created_at (oldest first for chat history)
        messages = messages.oldest_first.limit(limit).offset(offset)
        
        # Mark messages as read for current user
        @chat.mark_as_read_for(current_user)
        
        api_success(
          data: {
            chat: {
              id: @chat.id,
              other_user: chat_user_json(@chat.other_user(current_user))
            },
            messages: messages.map { |message| message_response(message) },
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

      # GET /api/v1/chats/:chat_id/messages/:id
      def show
        api_success(
          data: {
            message: message_response(@message)
          },
          status: :ok
        )
      end

      # POST /api/v1/chats/:chat_id/messages
      def create
        result = ChatMessageSender.deliver(
          chat: @chat,
          sender: current_user,
          content: message_params[:content],
          message_type: message_params[:message_type] || 'text',
          reply_to_id: message_params[:reply_to_id]
        )

        case result[:status]
        when :invalid
          api_validation_error(errors: result[:errors])
        else
          message = result[:message]
          unless result[:status] == :duplicate
            full = @chat.messages.includes(:sender, :forwarded_from, reply_to: :sender).find(message.id)
            ChatRealtimeDelivery.broadcast_new_message(@chat, full, chat_user_json(full.sender))
            recipient = @chat.other_user(full.sender)
            ChatMessagePushNotifier.notify_if_offline(recipient, @chat, full, full.sender)
          end

          api_success(
            data: { message: message_response(message) },
            message: 'Message sent successfully',
            status: result[:status] == :duplicate ? :ok : :created
          )
        end
      end

      # PATCH /api/v1/chats/:chat_id/messages/:id
      def edit
        unless @message.can_edit?(current_user)
          api_error(message: 'You can only edit your own messages within 15 minutes', status: :forbidden)
          return
        end

        new_content = params[:content]
        unless new_content.present?
          api_error(message: 'Content is required', status: :bad_request)
          return
        end

        @message.edit!(new_content)

        ChatRealtimeDelivery.broadcast_message_edited(@chat, current_user, @message)

        api_success(
          data: { message: message_response(@message) },
          message: 'Message edited successfully',
          status: :ok
        )
      end

      # DELETE /api/v1/chats/:chat_id/messages/:id
      def destroy
        unless @message.sender_id == current_user.id
          api_error(message: 'You can only delete your own messages', status: :forbidden)
          return
        end
        
        @message.soft_delete

        ChatRealtimeDelivery.broadcast_message_deleted(@chat, current_user, @message.id)

        api_success(message: 'Message deleted successfully', status: :ok)
      end

      # POST /api/v1/chats/:chat_id/messages/:id/forward
      def forward
        target_chat_id = params[:target_chat_id]
        target_chat = Chat.for_user(current_user).find_by(id: target_chat_id)
        
        unless target_chat
          api_error(message: 'Target chat not found', status: :not_found)
          return
        end

        # Create forwarded message
        forwarded_message = target_chat.messages.create!(
          sender: current_user,
          content: @message.content,
          message_type: @message.message_type,
          forwarded_from: @message
        )

        full = target_chat.messages.includes(:sender, :forwarded_from, reply_to: :sender).find(forwarded_message.id)
        ChatRealtimeDelivery.broadcast_new_message(target_chat, full, chat_user_json(full.sender))
        recipient = target_chat.other_user(full.sender)
        ChatMessagePushNotifier.notify_if_offline(recipient, target_chat, full, full.sender)

        api_success(
          data: { message: message_response(forwarded_message) },
          message: 'Message forwarded successfully',
          status: :created
        )
      end

      private

      def set_chat
        @chat = Chat.for_user(current_user)
                    .includes(user1: :venue_pr_partnerships, user2: :venue_pr_partnerships)
                    .find_by(id: params[:chat_id])
        unless @chat
          api_error(message: 'Chat not found', status: :not_found)
        end
      end

      def check_chat_access
        if @chat.blocked_by?(current_user)
          api_error(message: 'You have blocked this user', status: :forbidden)
        end
      end

      def set_message
        @message = @chat.messages.includes(sender: :venue_pr_partnerships).find_by(id: params[:id])
        unless @message
          api_error(message: 'Message not found', status: :not_found)
        end
      end

      def message_params
        params.require(:message).permit(:content, :message_type, :reply_to_id)
      end

      def message_response(message)
        {
          id: message.id,
          sender: chat_user_json(message.sender),
          content: message.content,
          message_type: message.message_type,
          reply_to: message.reply_to ? {
            id: message.reply_to.id,
            content: message.reply_to.content,
            sender_name: message.reply_to.sender.name
          } : nil,
          forwarded_from: message.forwarded? ? {
            id: message.forwarded_from_id,
            type: message.forwarded_from_type,
            content: message.forwarded_from.respond_to?(:content) ? message.forwarded_from.content : nil
          } : nil,
          is_edited: message.is_edited,
          edited_at: message.edited_at&.iso8601,
          is_read: message.is_read,
          read_at: message.read_at&.iso8601,
          deleted: message.deleted?,
          created_at: message.created_at.iso8601,
          updated_at: message.updated_at.iso8601
        }
      end
    end
  end
end

