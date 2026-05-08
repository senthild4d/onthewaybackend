# Run expired-booking cleanup (e.g. from cron):
#   rake booking:cleanup_incomplete
#   rake booking:cleanup_incomplete[5]         # default: 5 min expiry
#   rake booking:cleanup_incomplete[60]       # older than 60 minutes
#   rake booking:cleanup_incomplete[5,true]   # dry run
namespace :booking do
  desc 'Cancel bookings that expired (created status, not confirmed within expiry window). Default: 5 min.'
  task :cleanup_incomplete, [:older_than_minutes, :dry_run] => :environment do |_t, args|
    older = (args[:older_than_minutes] || Booking::EXPIRY_MINUTES).to_i
    dry = args[:dry_run].to_s == 'true'
    count = CleanupIncompleteBookingsJob.perform_now(older_than_minutes: older, dry_run: dry)
    puts "Cleanup complete. Cancelled: #{count}" unless dry
    puts "Dry run. Would have cancelled: #{count}" if dry
  end
end
