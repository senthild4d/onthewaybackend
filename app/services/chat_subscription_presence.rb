# frozen_string_literal: true

# Tracks whether a user currently has an active ChatChannel subscription for a chat
# (used to decide whether to send a push notification for a new message).
class ChatSubscriptionPresence
  KEY_PREFIX = "vibes:chat_sub:"
  TTL_SECONDS = 7.days.to_i

  class << self
    def mark_subscribed!(user_id, chat_id)
      redis&.setex(key(user_id, chat_id), TTL_SECONDS, "1")
    end

    def mark_unsubscribed!(user_id, chat_id)
      redis&.del(key(user_id, chat_id))
    end

    # When Redis is unavailable in development, assume the client may still be on WS (avoid FCM spam).
    # In production, missing Redis is treated as "not subscribed" so pushes can still fire.
    def subscribed?(user_id, chat_id)
      r = redis
      unless r
        return false if Rails.env.production?

        return true
      end

      r.exists?(key(user_id, chat_id))
    end

    private

    def key(user_id, chat_id)
      "#{KEY_PREFIX}#{user_id}:#{chat_id}"
    end

    def redis
      @redis ||= begin
        url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
        Redis.new(url: url)
      rescue StandardError => e
        Rails.logger.warn("[ChatSubscriptionPresence] Redis unavailable: #{e.message}")
        nil
      end
    end
  end
end
