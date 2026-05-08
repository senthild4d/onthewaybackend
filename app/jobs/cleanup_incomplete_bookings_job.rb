# Cancels bookings that expired (created status, not confirmed within expiry window).
# Bookings expire 5 minutes after creation if not paid (paid events) or not approved (free events).
#
# Run periodically (e.g. every 1–2 min) via cron or scheduler:
#   CleanupIncompleteBookingsJob.perform_later
#
# Options:
#   older_than_minutes: cancel only if booking created/expired this many minutes ago (default: 5)
#   dry_run: if true, only log what would be cancelled (default: false)
class CleanupIncompleteBookingsJob < ApplicationJob
  queue_as :default

  def perform(older_than_minutes: Booking::EXPIRY_MINUTES, dry_run: false)
    cutoff = older_than_minutes.to_i.minutes.ago
    scope = Booking
      .where(status: 'created')
      .where('created_at < ?', cutoff)
      .includes(:event)

    cancelled = 0
    scope.find_each do |booking|
      next unless should_expire?(booking, cutoff)

      if dry_run
        Rails.logger.info "[CleanupIncompleteBookingsJob] Would cancel booking #{booking.id} (event #{booking.event_id}, created #{booking.created_at})"
      else
        booking.cancel!
        cancelled += 1
        Rails.logger.info "[CleanupIncompleteBookingsJob] Cancelled expired booking #{booking.id} (event #{booking.event_id})"
      end
    end

    Rails.logger.info "[CleanupIncompleteBookingsJob] Done. Cancelled #{cancelled} expired booking(s)." unless dry_run
    cancelled
  end

  private

  def should_expire?(booking, cutoff)
    # Bookings in 'created' status expire after EXPIRY_MINUTES (5 min)
    expiry_time = booking.expiry_at || (booking.created_at + Booking::EXPIRY_MINUTES.minutes)
    expiry_time < Time.current
  end
end
