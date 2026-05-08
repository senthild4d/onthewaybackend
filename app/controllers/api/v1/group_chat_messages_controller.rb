module Api
  module V1
    class GroupChatMessagesController < ApplicationController
      before_action :require_authentication!
      before_action :set_group_chat
      before_action :check_group_chat_membership
      before_action :set_message, only: [:show, :destroy, :edit, :forward]

      # GET /api/v1/group_chats/:group_chat_id/messages
      def index
        messages = @group_chat.messages.not_deleted.includes(:user, :reply_to)
        
        # Filter by message type
        messages = messages.where(message_type: params[:message_type]) if params[:message_type].present?
        
        # Limit results
        limit = [params[:limit]&.to_i || 50, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = messages.count
        
        # Order by created_at (oldest first for chat history)
        messages = messages.oldest_first.limit(limit).offset(offset)
        
        # Mark messages as read for current user
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.mark_as_read
        
        api_success(
          data: {
            group_chat: {
              id: @group_chat.id,
              name: @group_chat.name
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

      # GET /api/v1/group_chats/:group_chat_id/messages/:id
      def show
        api_success(
          data: {
            message: message_response(@message)
          },
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:group_chat_id/messages
      def create
        message = @group_chat.messages.build(
          user: current_user,
          content: message_params[:content],
          message_type: message_params[:message_type] || 'text',
          reply_to_id: message_params[:reply_to_id]
        )
        
        if message.save
          # Broadcast via ActionCable
          ActionCable.server.broadcast(
            "group_chat_#{@group_chat.id}",
            {
              id: message.id,
              user: {
                id: message.user.id,
                name: message.user.name,
                username: message.user.username
              },
              content: message.content,
              message_type: message.message_type,
              reply_to: message.reply_to ? {
                id: message.reply_to.id,
                content: message.reply_to.content,
                user_name: message.reply_to.user.name
              } : nil,
              deleted: false,
              created_at: message.created_at.iso8601,
              updated_at: message.updated_at.iso8601
            }
          )
          
          api_success(
            data: { message: message_response(message) },
            message: 'Message sent successfully',
            status: :created
          )
        else
          api_validation_error(errors: message.errors.full_messages)
        end
      end

      # DELETE /api/v1/group_chats/:group_chat_id/messages/:id
      def destroy
        # Users can only delete their own messages
        unless @message.user_id == current_user.id || @group_chat.can_manage?(current_user) || current_user.role_admin?
          api_error(message: 'You can only delete your own messages', status: :forbidden)
          return
        end
        
        @message.soft_delete
        
        # Broadcast deletion via ActionCable
        ActionCable.server.broadcast(
          "group_chat_#{@group_chat.id}",
          {
            action: 'message_deleted',
            message_id: @message.id
          }
        )
        
        api_success(message: 'Message deleted successfully', status: :ok)
      end

      # PATCH /api/v1/group_chats/:group_chat_id/messages/:id
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
        
        # Broadcast edit via ActionCable
        ActionCable.server.broadcast(
          "group_chat_#{@group_chat.id}",
          {
            action: 'message_edited',
            message_id: @message.id,
            content: @message.content,
            edited_at: @message.edited_at.iso8601
          }
        )
        
        api_success(
          data: { message: message_response(@message) },
          message: 'Message edited successfully',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:group_chat_id/messages/:id/forward
      def forward
        target_group_chat_id = params[:target_group_chat_id]
        target_group_chat = GroupChat.find_by(id: target_group_chat_id)
        
        unless target_group_chat
          api_error(message: 'Target group chat not found', status: :not_found)
          return
        end

        unless target_group_chat.member?(current_user)
          api_error(message: 'You are not a member of the target group chat', status: :forbidden)
          return
        end

        # Create forwarded message
        forwarded_message = target_group_chat.messages.create!(
          user: current_user,
          content: @message.content,
          message_type: @message.message_type,
          forwarded_from: @message
        )

        # Broadcast to target group chat
        ActionCable.server.broadcast(
          "group_chat_#{target_group_chat.id}",
          {
            id: forwarded_message.id,
            user: {
              id: forwarded_message.user.id,
              name: forwarded_message.user.name,
              username: forwarded_message.user.username
            },
            content: forwarded_message.content,
            message_type: forwarded_message.message_type,
            forwarded_from: {
              id: @message.id,
              content: @message.content,
              user_name: @message.user.name,
              group_chat_name: @group_chat.name
            },
            created_at: forwarded_message.created_at.iso8601
          }
        )
        
        api_success(
          data: { message: message_response(forwarded_message) },
          message: 'Message forwarded successfully',
          status: :created
        )
      end

      private

      def set_group_chat
        @group_chat = GroupChat.find_by(id: params[:group_chat_id])
        unless @group_chat
          api_error(message: 'Group chat not found', status: :not_found)
        end
      end

      def check_group_chat_membership
        unless @group_chat&.member?(current_user)
          api_error(message: 'You are not a member of this group chat', status: :forbidden)
        end
      end

      def set_message
        @message = @group_chat.messages.find_by(id: params[:id])
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
          user: {
            id: message.user.id,
            name: message.user.name,
            username: message.user.username
          },
          content: message.content,
          message_type: message.message_type,
          reply_to: message.reply_to ? {
            id: message.reply_to.id,
            content: message.reply_to.content,
            user_name: message.reply_to.user.name
          } : nil,
          forwarded_from: message.forwarded? ? {
            id: message.forwarded_from_id,
            type: message.forwarded_from_type,
            content: message.forwarded_from.respond_to?(:content) ? message.forwarded_from.content : nil
          } : nil,
          is_edited: message.is_edited,
          edited_at: message.edited_at&.iso8601,
          deleted: message.deleted?,
          created_at: message.created_at.iso8601,
          updated_at: message.updated_at.iso8601
        }
      end
    end
  end
end

