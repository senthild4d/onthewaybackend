Rails.application.config.to_prepare do
  module ActionCableLogChatChannelCommands
    def execute_command(data)
      if data.is_a?(Hash) && (data['command'] == 'subscribe' || data['command'] == 'message')
        identifier = data['identifier']
        if identifier.is_a?(String) && identifier.include?('"channel":"ChatChannel"')
          Rails.logger.info("[ActionCable] cmd=#{data['command']} identifier=#{identifier}")
        end
      end

      super
    end
  end

  module ActionCableIgnoreMissingSubscription
    def handle_channel_command(payload)
      super
    rescue StandardError => e
      # ActionCable logs a noisy exception when a client sends a `message` command
      # for an identifier that has not successfully subscribed.
      if e.message.to_s.start_with?("Unable to find subscription with identifier:")
        Rails.logger.warn("[ActionCable] #{e.message}")
        return
      end

      raise
    end
  end

  unless ActionCable::Connection::Subscriptions.ancestors.include?(ActionCableLogChatChannelCommands)
    ActionCable::Connection::Subscriptions.prepend(ActionCableLogChatChannelCommands)
  end

  unless ActionCable::Connection::Base.ancestors.include?(ActionCableIgnoreMissingSubscription)
    ActionCable::Connection::Base.prepend(ActionCableIgnoreMissingSubscription)
  end
end

