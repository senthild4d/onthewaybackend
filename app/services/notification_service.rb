# Sends and persists notifications.
# Creates a DB Notification record and (optionally) pushes via FCM to user's devices.
class NotificationService
  class << self
    # Send notification to a single user.
    # @param user [User]
    # @param title [String]
    # @param body [String]
    # @param notification_type [String] one of Notification::TYPES
    # @param data [Hash] payload (will be sent to FCM as strings)
    # @param related [ActiveRecord::Base] optional related record (Property, PropertyViewing, etc.)
    # @param push [Boolean] whether to send push notification (default: true)
    # @return [Notification] the saved notification record
    def send_to_user(user, title:, body: nil, notification_type: 'system', data: {}, related: nil, push: true)
      return nil unless user.is_a?(User)

      notification = Notification.create!(
        user_id: user.id,
        notification_type: notification_type,
        title: title,
        body: body,
        data: data || {},
        related_type: related&.class&.name,
        related_id: related&.id
      )

      if push
        push_data = (data || {}).merge(
          notification_id: notification.id.to_s,
          notification_type: notification_type
        )
        push_data[:related_type] = related.class.name if related
        push_data[:related_id] = related.id.to_s if related

        FcmService.send_to_user(
          user,
          title: title,
          body: body.to_s,
          data: push_data
        )
      end

      notification
    rescue => e
      Rails.logger.error "NotificationService error: #{e.message}"
      nil
    end

    # Send notification to multiple users
    def send_to_users(users, **opts)
      Array(users).map { |u| send_to_user(u, **opts) }.compact
    end
  end
end
