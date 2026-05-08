class CreateBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :bookings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.string :status, default: 'confirmed', null: false
      t.datetime :checked_in_at
      t.text :notes
      
      t.timestamps
    end
    
    add_index :bookings, :status
    add_index :bookings, :checked_in_at
    add_index :bookings, [:user_id, :event_id], unique: true, name: 'index_bookings_user_event_unique'
    add_check_constraint :bookings, "status IN ('confirmed', 'canceled', 'checked_in')", name: 'check_booking_status'
  end
end

