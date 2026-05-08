# Hard-deletes unpaid booking holds that stayed in `created` long after expiry_at
# (e.g. cleanup job did not run). Run daily via scheduler.
class DeleteStaleExpiredBookingHoldsJob < ApplicationJob
  queue_as :default

  def perform(older_than_hours: 24)
    cutoff = older_than_hours.to_i.hours.ago
    deleted = Booking.where(status: 'created')
                     .where.not(expiry_at: nil)
                     .where('expiry_at < ?', cutoff)
                     .delete_all
    Rails.logger.info "[DeleteStaleExpiredBookingHoldsJob] Deleted #{deleted} stale expired booking row(s)"
    deleted
  end
end
