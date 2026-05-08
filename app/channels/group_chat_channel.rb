class GroupChatChannel < ApplicationCable::Channel
  def subscribed
    @group_chat = GroupChat.find_by(id: params[:group_chat_id])
    return reject unless @group_chat

    # Check if user is a member of the group chat
    unless @group_chat.members.include?(current_user)
      return reject
    end

    stream_from "group_chat_#{params[:group_chat_id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def speak(data)
    return unless @group_chat&.members.include?(current_user)

    message = @group_chat.messages.create!(
      user: current_user,
      content: data['content'],
      message_type: data['message_type'] || 'text',
      reply_to_id: data['reply_to_id']
    )

    # Broadcast the message to all subscribers
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
  rescue ActiveRecord::RecordInvalid => e
    transmit({ error: e.message, status: 422 })
  end
end

