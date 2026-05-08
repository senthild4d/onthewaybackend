# frozen_string_literal: true

# 1:1 chat WebSocket payloads go to per-recipient streams so the sender does not receive
# their own message again over the cable (REST or speak already confirms to sender).
class ChatRealtimeDelivery
  class << self
    def stream_name(chat_id, recipient_user_id)
      "chat_#{chat_id}_recipient_#{recipient_user_id}"
    end

    def broadcast_new_message(chat, message, sender_payload)
      recipient = chat.other_user(message.sender)
      ActionCable.server.broadcast(
        stream_name(chat.id, recipient.id),
        new_message_payload(message, sender_payload)
      )
    end

    def broadcast_message_edited(chat, acting_user, message)
      recipient = chat.other_user(acting_user)
      ActionCable.server.broadcast(
        stream_name(chat.id, recipient.id),
        {
          action: 'message_edited',
          message_id: message.id,
          content: message.content,
          edited_at: message.edited_at.iso8601
        }
      )
    end

    def broadcast_message_deleted(chat, acting_user, message_id)
      recipient = chat.other_user(acting_user)
      ActionCable.server.broadcast(
        stream_name(chat.id, recipient.id),
        {
          action: 'message_deleted',
          message_id: message_id
        }
      )
    end

    private

    def new_message_payload(message, sender_payload)
      h = {
        action: 'new_message',
        chat_id: message.chat_id,
        id: message.id,
        sender: sender_payload,
        content: message.content,
        message_type: message.message_type,
        reply_to: message.reply_to ? {
          id: message.reply_to.id,
          content: message.reply_to.content,
          sender_name: message.reply_to.sender&.name
        } : nil,
        deleted: false,
        created_at: message.created_at.iso8601,
        updated_at: message.updated_at.iso8601
      }
      if message.forwarded?
        h[:forwarded_from] = {
          id: message.forwarded_from_id,
          type: message.forwarded_from_type,
          content: message.forwarded_from.respond_to?(:content) ? message.forwarded_from.content : nil
        }
      end
      h
    end
  end
end
