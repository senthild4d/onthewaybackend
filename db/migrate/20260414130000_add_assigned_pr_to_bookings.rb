class AddAssignedPrToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :assigned_pr_user_id, :uuid
    add_column :bookings, :assigned_pr_assigned_by_id, :uuid
    add_column :bookings, :assigned_pr_assigned_at, :datetime

    add_index :bookings, :assigned_pr_user_id
    add_index :bookings, :assigned_pr_assigned_by_id

    add_foreign_key :bookings, :users, column: :assigned_pr_user_id, on_delete: :nullify
    add_foreign_key :bookings, :users, column: :assigned_pr_assigned_by_id, on_delete: :nullify
  end
end

