# frozen_string_literal: true

# Push + in-app notification when the recipient is not actively subscribed to ChatChannel.
class ChatMessagePushNotifier
  class << self
    def notify_if_offline(recipient, chat, message, sender)
      return if recipient.blank? || message.blank?
      return if sender.present? && recipient.id == sender.id
      return unless chat_push_enabled?(recipient)

      if ChatSubscriptionPresence.subscribed?(recipient.id, chat.id)
        Rails.logger.info("[ChatMessagePushNotifier] skip push: recipient subscribed chat_id=#{chat.id} user_id=#{recipient.id}")
        return
      end

      create_notification_and_push(recipient, chat, message, sender)
    end

    private

    def chat_push_enabled?(user)
      prefs = user.preferences.is_a?(Hash) ? user.preferences : {}
      settings = prefs["push_notification_settings"]
      settings = settings.is_a?(Hash) ? settings : {}
      merged = Api::V1::UsersController::PUSH_NOTIFICATION_SETTINGS_DEFAULTS.deep_merge(settings)
      merged.dig("chat", "direct_messages") != false
    rescue StandardError
      true
    end

    def create_notification_and_push(recipient, chat, message, sender)
      preview = message.content.to_s.truncate(120)
      notification = Notification.create!(
        user: recipient,
        notification_type: "message",
        title: sender.name.presence || "New message",
        message: preview,
        metadata: {
          chat_id: chat.id,
          message_id: message.id,
          sender_id: sender.id
        }
      )

      return unless FcmService.configured?

      FcmService.send_to_user(
        recipient,
        title: notification.title,
        body: notification.message,
        data: {
          "notification_id" => notification.id.to_s,
          "notification_type" => "message",
          "chat_id" => chat.id.to_s,
          "message_id" => message.id.to_s,
          "sender_id" => sender.id.to_s
        }
      )
    rescue StandardError => e
      Rails.logger.error("[ChatMessagePushNotifier] #{e.class}: #{e.message}")
    end
  end
end
