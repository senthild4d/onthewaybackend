class AddCurrentLocationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :current_location, :jsonb, default: {}, null: false
  end
end

