# frozen_string_literal: true

class UserNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from PropertyRealtimeService.user_stream(current_user)
  end

  def unsubscribed
    # no-op
  end
end
