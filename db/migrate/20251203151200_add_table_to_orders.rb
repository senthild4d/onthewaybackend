class AddTableToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :food_bar_orders, :table_number, :string
    add_index :food_bar_orders, :table_number
  end
end

