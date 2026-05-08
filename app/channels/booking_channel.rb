# Real-time updates for a single booking: payment status, table assignment, check-in.
# Subscribe with booking_id. Allowed: booking owner, event venue owner, admin.
class BookingChannel < ApplicationCable::Channel
  def subscribed
    if ActiveModel::Type::Boolean.new.cast(ENV.fetch('BOOKING_CHANNEL_DEBUG', Rails.env.development?))
      begin
        cfg = ActiveRecord::Base.connection_db_config
        Rails.logger.info "[BookingChannel] DB=#{cfg.name} host=#{cfg.configuration_hash[:host]} database=#{cfg.database}"
        Rails.logger.info "[BookingChannel] booking_id=#{params[:booking_id]} exists?=#{Booking.where(id: params[:booking_id]).exists?}"
      rescue => e
        Rails.logger.info "[BookingChannel] DB debug failed: #{e.class}: #{e.message}"
      end
    end

    @booking = Booking.find_by(id: params[:booking_id])
    unless @booking
      Rails.logger.info "[BookingChannel] Rejected: booking not found id=#{params[:booking_id]}"
      return reject
    end

    unless can_subscribe?(@booking)
      Rails.logger.info "[BookingChannel] Rejected: user=#{current_user.id} not allowed for booking=#{@booking.id} (owner=#{@booking.user_id}, venue_owner=#{@booking.event&.venue&.owner_id})"
      return reject
    end

    stream_from "booking_#{@booking.id}"
    Rails.logger.info "[BookingChannel] Subscribed: user=#{current_user.id} → booking=#{@booking.id}"
  end

  def unsubscribed
    # cleanup
  end

  private

  def can_subscribe?(booking)
    return true if booking.user_id == current_user.id
    return true if current_user.role_admin?
    return true if booking.event&.venue&.owner_id == current_user.id
    false
  end
end
