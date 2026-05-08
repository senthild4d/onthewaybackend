# Booking Maintenance

## 1. Table exclusivity and check-out

### One table per booking

- A table can be assigned to **only one** booking per event at a time.
- When creating a booking with `table_number`, or when assigning a table via **assign_table**, the API checks that the table is not already in use by another booking (status `created`, `confirmed`, or `checked_in`).
- If the table is already booked for that event, the API returns **422** with message: *"This table is already booked for this event"*.

### Freeing the table when the guest leaves

- When a guest leaves, venue staff should call **check_out** so the table can be reused.
- **Endpoint:** `POST /api/v1/bookings/:id/check_out`
- **Who can call:** Venue owner (same as check_in).
- **Effect:** Clears `table_number`, `assigned_by_id`, and `table_assigned_at` on the booking. The booking remains in status `checked_in`; only the table assignment is removed.
- Subscribed clients receive a `check_out` WebSocket event so the app can update the UI.

**Flow:**

1. Guest arrives → staff **check_in** → booking is `checked_in`, table is occupied.
2. Guest leaves → staff **check_out** → table is freed; same table can be assigned to another booking.

---

## 2. Incomplete bookings (no / insufficient payment)

Bookings that never receive at least the required payment (e.g. pre-booking payment) should not hold capacity or tables indefinitely.

### What is “incomplete”

- Status is **created** (not confirmed/canceled/checked_in).
- Payment status is **pending**.
- **Either:**
  - No payment at all (`paid_amount == 0`), or
  - Event has pre-booking and `paid_amount < event.pre_booking_price`.
- Booking was **created more than X minutes ago** (e.g. 30), so new bookings are not cancelled immediately.

### How we cancel them

A job **CleanupIncompleteBookingsJob** finds such bookings and calls `booking.cancel!` (no refund, since no or insufficient payment).

**Run manually (rake):**

```bash
# Cancel incomplete bookings older than 30 minutes (default)
rake booking:cleanup_incomplete

# Older than 60 minutes
rake booking:cleanup_incomplete[60]

# Dry run (only log, do not cancel)
rake booking:cleanup_incomplete[30,true]
```

**Run as a one-off from Rails console:**

```ruby
CleanupIncompleteBookingsJob.perform_now(older_than_minutes: 30, dry_run: false)
```

**Run periodically (recommended)**

Schedule the job every 15–30 minutes, for example:

- **Cron:**  
  `*/30 * * * * cd /path/to/vibes && rake booking:cleanup_incomplete RAILS_ENV=production`
- **Whenever (if you use it):** add a job in `config/schedule.rb` that runs every 30 minutes.
- **Sidekiq / Active Job scheduler:** enqueue `CleanupIncompleteBookingsJob` every 30 minutes with `older_than_minutes: 30`.

**Options**

- `older_than_minutes`: only cancel bookings created more than this many minutes ago (default: 30).
- `dry_run: true`: only log which bookings would be cancelled; no changes.

---

## Summary

| Concern | Behaviour |
|--------|------------|
| **Same table twice** | Rejected on create (with table_number) and on assign_table; table is exclusive per event. |
| **Free table after guest leaves** | Staff call `POST /api/v1/bookings/:id/check_out`; table_number is cleared and table can be reused. |
| **Incomplete bookings** | Run `CleanupIncompleteBookingsJob` (or `rake booking:cleanup_incomplete`) periodically to cancel created/pending bookings with no or insufficient payment. |
