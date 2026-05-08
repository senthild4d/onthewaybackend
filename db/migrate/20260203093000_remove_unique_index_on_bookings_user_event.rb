class RemoveUniqueIndexOnBookingsUserEvent < ActiveRecord::Migration[7.0]
  def change
    remove_index :bookings, name: 'index_bookings_user_event_unique'
    add_index :bookings, [:user_id, :event_id]
  end
end
