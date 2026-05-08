class AddTimeWindowToFoodBarOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :food_bar_orders, :time_window_start, :datetime
    add_column :food_bar_orders, :time_window_end, :datetime

    add_index :food_bar_orders, :time_window_start
    add_index :food_bar_orders, :time_window_end

    add_check_constraint :food_bar_orders,
      "(time_window_start IS NULL OR time_window_end IS NULL) OR (time_window_end >= time_window_start)",
      name: 'check_food_bar_order_time_window'
  end
end
