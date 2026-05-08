class AddPartialPaymentSupportToBookings < ActiveRecord::Migration[8.0]
  def change
    # Add paid_amount to track cumulative payments
    add_column :bookings, :paid_amount, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    
    # Add payment_type to track payment type (pre_payment, partial, full, overpayment)
    add_column :bookings, :payment_type, :string
    
    # Change payment_status constraint to include 'partial'
    remove_check_constraint :bookings, name: "check_booking_payment_status"
    add_check_constraint :bookings, 
      "payment_status::text = ANY (ARRAY['pending'::character varying, 'partial'::character varying, 'paid'::character varying, 'failed'::character varying, 'refunded'::character varying]::text[])", 
      name: "check_booking_payment_status"
    
    # Add index for payment_type
    add_index :bookings, :payment_type
    
    # Add validation constraint for paid_amount
    # Note: We allow paid_amount to exceed price for overpayments (e.g., including pre-orders)
    add_check_constraint :bookings, "paid_amount >= 0::numeric", name: "check_booking_paid_amount"
  end
end
