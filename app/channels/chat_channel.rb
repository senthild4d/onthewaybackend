class ChatChannel < ApplicationCable::Channel
  include ChatUserPayload

  def subscribed
    chat_id = params[:chat_id].to_s

    if already_subscribed_on_connection?(chat_id)
      Rails.logger.info("[ChatChannel] reject_subscription duplicate_on_connection chat_id=#{chat_id} user_id=#{current_user&.id}")
      return reject
    end

    @chat = Chat.find_by(id: chat_id)
    unless @chat
      Rails.logger.info("[ChatChannel] reject_subscription chat_not_found chat_id=#{chat_id} user_id=#{current_user&.id}")
      return reject
    end

    # Check if user is part of this chat
    unless @chat.user1_id == current_user.id || @chat.user2_id == current_user.id
      Rails.logger.info(
        "[ChatChannel] reject_subscription not_a_member chat_id=#{@chat.id} user_id=#{current_user&.id} " \
        "user1_id=#{@chat.user1_id} user2_id=#{@chat.user2_id}"
      )
      return reject
    end

    # Check if user has blocked the other user
    if @chat.blocked_by?(current_user)
      Rails.logger.info("[ChatChannel] reject_subscription blocked_by_self chat_id=#{@chat.id} user_id=#{current_user&.id}")
      return reject
    end

    stream_from ChatRealtimeDelivery.stream_name(@chat.id, current_user.id)
    ChatSubscriptionPresence.mark_subscribed!(current_user.id, @chat.id)
    Rails.logger.info("[ChatChannel] Subscribed: user=#{current_user&.id} → chat=#{@chat.id}")
  end

  def unsubscribed
    return unless @chat

    ChatSubscriptionPresence.mark_unsubscribed!(current_user.id, @chat.id)
    unsubscribe_on_connection!(@chat.id.to_s)
  end

  def speak(data)
    return unless @chat && (@chat.user1_id == current_user.id || @chat.user2_id == current_user.id)
    return if @chat.blocked_by?(current_user)

    result = ChatMessageSender.deliver(
      chat: @chat,
      sender: current_user,
      content: data['content'] || data[:content],
      message_type: data['message_type'] || data[:message_type] || 'text',
      reply_to_id: data['reply_to_id'] || data[:reply_to_id]
    )

    case result[:status]
    when :invalid
      transmit({ error: result[:errors].join(', '), status: 422 })
    when :duplicate
      # Same send already persisted (e.g. REST + Cable); recipient was notified once.
      nil
    else
      message = result[:message]
      full = ChatMessage.includes(:sender, :forwarded_from, reply_to: :sender).find(message.id)
      ChatRealtimeDelivery.broadcast_new_message(@chat, full, chat_user_json(full.sender))
      recipient = @chat.other_user(full.sender)
      ChatMessagePushNotifier.notify_if_offline(recipient, @chat, full, full.sender)
    end
  end

  private

  def already_subscribed_on_connection?(chat_id)
    subs = connection.instance_variable_get(:@_chat_channel_subscriptions)
    subs = {} unless subs.is_a?(Hash)
    return true if subs[chat_id]

    subs[chat_id] = true
    connection.instance_variable_set(:@_chat_channel_subscriptions, subs)
    false
  end

  def unsubscribe_on_connection!(chat_id)
    subs = connection.instance_variable_get(:@_chat_channel_subscriptions)
    return unless subs.is_a?(Hash)

    subs.delete(chat_id)
    connection.instance_variable_set(:@_chat_channel_subscriptions, subs)
  end
end

