class AddCancellationPolicyToEvents < ActiveRecord::Migration[8.0]
  def change
    # Add cancellation policy fields to events
    # These fields determine the refund policy when users cancel their bookings
    add_column :events, :cancellation_policy_enabled, :boolean, default: false, null: false
    add_column :events, :cancellation_deadline_hours, :integer, comment: 'Hours before event when full refund is available (e.g., 24 = cancel 24 hours before)'
    add_column :events, :cancellation_fee_percentage, :decimal, precision: 5, scale: 2, default: 0.0, comment: 'Percentage of booking price charged as cancellation fee after deadline (0-100)'
    
    # Add indexes
    add_index :events, :cancellation_policy_enabled
    
    # Add check constraints
    add_check_constraint :events, 
      'cancellation_deadline_hours IS NULL OR cancellation_deadline_hours >= 0',
      name: 'check_cancellation_deadline_hours'
    
    add_check_constraint :events,
      'cancellation_fee_percentage >= 0 AND cancellation_fee_percentage <= 100',
      name: 'check_cancellation_fee_percentage'
  end
end

