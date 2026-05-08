class AddTableNumberToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :table_number, :string
    add_column :bookings, :assigned_by_id, :uuid
    add_column :bookings, :table_assigned_at, :datetime
    
    add_index :bookings, :table_number
    add_foreign_key :bookings, :users, column: :assigned_by_id, on_delete: :nullify
  end
end

