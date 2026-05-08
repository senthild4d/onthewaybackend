require 'uri'

# Broadcasts real-time booking updates over ActionCable (payment, table assignment, check-in).
# Subscribers use BookingChannel with booking_id.
class BookingBroadcaster
  class << self
    def broadcast(booking, action, extra = {})
      payload = {
        action: action,
        booking_id: booking.id,
        booking: booking.websocket_detail_payload
      }.merge(extra)
      stream = "booking_#{booking.id}"

      receivers = ActionCable.server.broadcast(stream, payload)
      booking_cable_broadcast_debug(stream, receivers, payload) if booking_cable_debug?

      receivers
    end

    def payment_completed(booking, amount: nil)
      broadcast(booking, 'payment_completed', amount: amount&.to_f)
    end

    def payment_failed(booking)
      broadcast(booking, 'payment_failed')
    end

    def table_assigned(booking, table_number: nil)
      broadcast(booking, 'table_assigned', table_number: (table_number || booking.table_number))
    end

    def check_in(booking)
      broadcast(booking, 'check_in')
    end

    def check_out(booking)
      broadcast(booking, 'check_out')
    end

    def status_updated(booking)
      broadcast(booking, 'status_updated')
    end

    def price_updated(booking)
      broadcast(booking, 'price_updated')
    end

    def venue_approved(booking)
      broadcast(booking, 'venue_approved')
    end

    private

    def booking_cable_debug?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('BOOKING_CABLE_DEBUG', Rails.env.development?))
    end

    def sanitize_redis_url(raw)
      return nil if raw.blank?

      uri = URI.parse(raw.to_s)
      uri.user = nil
      uri.password = nil if uri.respond_to?(:password=)
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    # ActionCable.broadcast return type varies by adapter/version — log what we got.
    def booking_cable_broadcast_debug(stream, receivers, payload)
      pubsub = ActionCable.server.pubsub
      adapter = pubsub&.class&.name
      redis_url = sanitize_redis_url(ENV['REDIS_URL'])
      receivers_info =
        case receivers
        when Integer then "subscriber_streams=#{receivers}"
        when Array then "streams=#{receivers.size}"
        when NilClass then 'subscriber_streams=nil'
        else "returned=#{receivers.class.name}"
        end

      Rails.logger.info(
        "[BookingBroadcaster] broadcast stream=#{stream} action=#{payload[:action]} adapter=#{adapter} #{receivers_info} redis_url=#{redis_url.inspect}"
      )

      if adapter.to_s.include?('Async')
        Rails.logger.warn(
          "[BookingBroadcaster] ActionCable pubsub adapter is #{adapter}. Broadcasts will NOT reliably reach `/cable` connections " \
          "handled by separate Puma/ActionCable worker processes unless you use the Redis adapter (set REDIS_URL + ensure Rails uses `config/cable.yml` prod settings)."
        )
      end

      return unless redis_url.nil? && !Rails.env.development?

      Rails.logger.warn(
        "[BookingBroadcaster] ENV['REDIS_URL'] is blank in #{Rails.env}. If your websocket server uses Redis for ActionCable, " \
          "run this console/worker with the same REDIS_URL as Puma/Cable or broadcasts from Pry may not reach clients."
      )
    end
  end
end
