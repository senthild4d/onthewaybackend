# frozen_string_literal: true

# Persists 1:1 chat messages from REST and ActionCable. Clients often send the same message
# twice (e.g. POST + Cable speak); we collapse identical payloads within a short window.
class ChatMessageSender
  DEDUP_WINDOW = 1.second

  class << self
    # @return [Hash] one of:
    #   { status: :created, message: ChatMessage }
    #   { status: :duplicate, message: ChatMessage } — same row as a very recent send; skip rebroadcast
    #   { status: :invalid, errors: Array<String> }
    def deliver(chat:, sender:, content:, message_type: 'text', reply_to_id: nil)
      mt = (message_type.presence || 'text').to_s
      reply_key = reply_to_id.presence

      chat.with_lock do
        scope = chat.messages.not_deleted.where(
          sender_id: sender.id,
          message_type: mt,
          content: content
        ).where('chat_messages.created_at > ?', DEDUP_WINDOW.ago)

        scope =
          if reply_key
            scope.where(reply_to_id: reply_key)
          else
            scope.where(reply_to_id: nil)
          end

        existing = scope.order(created_at: :desc).first
        return { status: :duplicate, message: existing } if existing

        message = chat.messages.build(
          sender: sender,
          content: content,
          message_type: mt,
          reply_to_id: reply_key
        )
        unless message.save
          return { status: :invalid, errors: message.errors.full_messages }
        end

        { status: :created, message: message }
      end
    end
  end
end
