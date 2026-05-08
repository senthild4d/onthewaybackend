# Event option: booking is allowed only after event start (e.g. when stream goes live).
# See docs/STREAM_AND_MOMENTS_SPEC.md
class AddBookingOpensAfterEventStartToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :booking_opens_after_event_start, :boolean, default: false, null: false
  end
end
