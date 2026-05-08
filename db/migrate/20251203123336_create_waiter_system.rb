class CreateWaiterSystem < ActiveRecord::Migration[8.0]
  def change
    # Venue staff/waiters
    create_table :venue_staff, id: :uuid do |t|
      t.uuid :venue_id, null: false
      t.uuid :user_id, null: false
      t.string :role, default: 'waiter', null: false # 'waiter', 'bartender', 'chef', 'manager'
      t.string :status, default: 'active', null: false # 'active', 'on_break', 'off_duty', 'inactive'
      t.boolean :receives_notifications, default: true, null: false
      t.decimal :current_latitude, precision: 10, scale: 7
      t.decimal :current_longitude, precision: 10, scale: 7
      t.datetime :last_location_update
      t.datetime :shift_start_at
      t.datetime :shift_end_at
      t.timestamps
    end

    add_index :venue_staff, :venue_id
    add_index :venue_staff, :user_id
    add_index :venue_staff, [:venue_id, :user_id], unique: true
    add_index :venue_staff, :role
    add_index :venue_staff, :status
    add_foreign_key :venue_staff, :venues, on_delete: :cascade
    add_foreign_key :venue_staff, :users, on_delete: :cascade

    # Waiter calls
    create_table :waiter_calls, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.uuid :user_id, null: false # Customer calling
      t.uuid :booking_id
      t.uuid :order_id # Optional link to order if calling about order
      t.string :call_type, default: 'assistance', null: false # 'assistance', 'order_help', 'bill_request', 'complaint', 'emergency'
      t.text :message
      t.string :status, default: 'pending', null: false # 'pending', 'acknowledged', 'in_progress', 'completed', 'canceled'
      t.uuid :assigned_staff_id # Waiter who responded
      t.decimal :user_latitude, precision: 10, scale: 7
      t.decimal :user_longitude, precision: 10, scale: 7
      t.string :table_number
      t.string :location_description
      t.datetime :acknowledged_at
      t.datetime :completed_at
      t.datetime :canceled_at
      t.timestamps
    end

    add_index :waiter_calls, :event_id
    add_index :waiter_calls, :user_id
    add_index :waiter_calls, :booking_id
    add_index :waiter_calls, :order_id
    add_index :waiter_calls, :call_type
    add_index :waiter_calls, :status
    add_index :waiter_calls, :assigned_staff_id
    add_index :waiter_calls, :created_at
    add_foreign_key :waiter_calls, :events, on_delete: :cascade
    add_foreign_key :waiter_calls, :users, on_delete: :cascade
    add_foreign_key :waiter_calls, :bookings, on_delete: :nullify
    add_foreign_key :waiter_calls, :food_bar_orders, column: :order_id, on_delete: :nullify
    add_foreign_key :waiter_calls, :venue_staff, column: :assigned_staff_id, on_delete: :nullify

    # QR code splits
    create_table :split_qr_codes, id: :uuid do |t|
      t.uuid :food_bar_order_id, null: false
      t.string :qr_token, null: false
      t.integer :max_participants
      t.integer :current_participants, default: 1, null: false
      t.string :status, default: 'active', null: false # 'active', 'completed', 'expired'
      t.datetime :expires_at
      t.timestamps
    end

    add_index :split_qr_codes, :food_bar_order_id
    add_index :split_qr_codes, :qr_token, unique: true
    add_index :split_qr_codes, :status
    add_foreign_key :split_qr_codes, :food_bar_orders, on_delete: :cascade

    # Check constraints
    add_check_constraint :venue_staff,
      "role IN ('waiter', 'bartender', 'chef', 'manager', 'host')",
      name: 'check_venue_staff_role'

    add_check_constraint :venue_staff,
      "status IN ('active', 'on_break', 'off_duty', 'inactive')",
      name: 'check_venue_staff_status'

    add_check_constraint :waiter_calls,
      "call_type IN ('assistance', 'order_help', 'bill_request', 'complaint', 'emergency')",
      name: 'check_waiter_call_type'

    add_check_constraint :waiter_calls,
      "status IN ('pending', 'acknowledged', 'in_progress', 'completed', 'canceled')",
      name: 'check_waiter_call_status'

    add_check_constraint :split_qr_codes,
      "status IN ('active', 'completed', 'expired')",
      name: 'check_split_qr_code_status'

    add_check_constraint :split_qr_codes,
      "current_participants <= max_participants OR max_participants IS NULL",
      name: 'check_split_qr_participants'
  end
end

