# frozen_string_literal: true

# Notifies venue team when a booking requires RSVP approval (free or paid).
class BookingNotificationService
  class << self
    def notify_venue_for_booking_request(booking)
      return unless booking.present?
      return unless should_notify_venue_team?(booking)

      venue = booking.event&.venue
      return unless venue&.owner

      event = booking.event
      user = booking.user

      title = 'New booking request'
      payment_hint =
        if booking.free?
          'Free booking.'
        elsif booking.payment_status_paid? && booking.fully_paid?
          'Payment received.'
        else
          'Payment pending.'
        end
      message = "#{user&.name || 'A user'} requested to book \"#{event.title}\". #{payment_hint} Please approve or reject."

      recipients = booking_request_recipients_for_venue(venue)
      return if recipients.empty?

      notifications = recipients.map do |recipient|
        existing = existing_booking_request_notification(recipient, booking)
        next existing if existing

        notification = Notification.create!(
          user: recipient,
          notification_type: 'booking_request',
          title: title,
          message: message,
          metadata: {
            booking_id: booking.id,
            event_id: event.id,
            event_title: event.title,
            user_id: user.id,
            user_name: user&.name,
            user_username: user&.username,
            attendees_count: booking.total_attendees_count,
            price: booking.price.to_f,
            currency: booking.currency,
            is_free: booking.free?
          }
        )

        send_push_notification(recipient, notification)
        notification
      end

      notifications.compact
    rescue => e
      Rails.logger.error "BookingNotificationService: Failed to notify venue: #{e.message}"
      nil
    end

    private

    def existing_booking_request_notification(recipient, booking)
      return nil unless recipient&.id && booking&.id

      scope = Notification.where(user_id: recipient.id, notification_type: 'booking_request')

      adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
      booking_id = booking.id.to_s

      # Prefer JSON/JSONB lookup when available (Postgres).
      if adapter.include?('postgres')
        scope = scope.where("metadata ->> 'booking_id' = ?", booking_id)
      else
        # Fallback: coarse text match (works for SQLite/MySQL but less strict).
        scope = scope.where("metadata LIKE ?", "%\"booking_id\"%#{booking_id}%")
      end

      scope.order(created_at: :desc).first
    rescue
      nil
    end

    # 1) Ticket mode + within 24h of event start: do not notify venue/PR (sales window closed).
    # 2) RSVP mode: keep notifying while the venue has RSVP enabled; if venue disables RSVP, stop.
    def should_notify_venue_team?(booking)
      event = booking.event
      return false unless event

      if event.tickets_mode? && event.tickets_closed?
        return false
      end

      if event.attendance_mode == 'rsvp' || event.attendance_mode.blank?
        return false unless event.venue_rsvp_enabled?
      end

      true
    end

    def booking_request_recipients_for_venue(venue)
      recipients = []
      recipients << venue.owner if venue.owner

      # Active PR users partnered to this venue
      recipients.concat(venue.active_pr_partnerships.includes(:user).map(&:user)) if venue.respond_to?(:active_pr_partnerships)

      # Venue staff managers
      if venue.respond_to?(:venue_staff)
        recipients.concat(venue.venue_staff.active.by_role('manager').includes(:user).map(&:user))
      end

      recipients.compact.uniq
    end

    def send_push_notification(user, notification)
      return unless FcmService.configured?

      meta = notification.metadata_hash
      FcmService.send_to_user(
        user,
        title: notification.title,
        body: notification.message,
        data: meta.deep_stringify_keys.merge(
          "notification_id" => notification.id.to_s,
          "notification_type" => "booking_request",
          "booking_id" => meta["booking_id"].to_s,
          "event_id" => meta["event_id"].to_s
        ).transform_values(&:to_s)
      )
    end
  end
end
