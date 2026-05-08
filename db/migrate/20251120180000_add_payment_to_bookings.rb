class AddPaymentToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :price, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    add_column :bookings, :currency, :string, default: 'USD', null: false
    add_column :bookings, :payment_status, :string, default: 'pending', null: false
    add_column :bookings, :payment_transaction_id, :uuid
    add_column :bookings, :payment_method, :string
    add_column :bookings, :paid_at, :datetime
    add_index :bookings, :payment_status
    add_index :bookings, :payment_transaction_id
    add_foreign_key :bookings, :payment_transactions, column: :payment_transaction_id, on_delete: :nullify
    add_check_constraint :bookings, "payment_status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'failed'::character varying, 'refunded'::character varying]::text[])", name: "check_booking_payment_status"
  end
end

