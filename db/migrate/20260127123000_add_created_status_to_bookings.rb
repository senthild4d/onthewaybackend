class AddCreatedStatusToBookings < ActiveRecord::Migration[8.0]
  def change
    change_column_default :bookings, :status, from: 'confirmed', to: 'created'

    remove_check_constraint :bookings, name: 'check_booking_status'
    add_check_constraint :bookings,
      "status IN ('created', 'confirmed', 'canceled', 'checked_in')",
      name: 'check_booking_status'
  end
end
