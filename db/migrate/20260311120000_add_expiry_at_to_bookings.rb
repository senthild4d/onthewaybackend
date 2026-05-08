class AddExpiryAtToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :expiry_at, :datetime
  end
end
