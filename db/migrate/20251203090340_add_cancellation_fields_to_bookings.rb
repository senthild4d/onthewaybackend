class AddCancellationFieldsToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :canceled_at, :datetime
    add_column :bookings, :refund_amount, :decimal, precision: 10, scale: 2
    add_column :bookings, :cancellation_fee, :decimal, precision: 10, scale: 2
    
    add_index :bookings, :canceled_at
  end
end

