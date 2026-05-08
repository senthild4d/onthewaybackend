class CreateFoodBarOrders < ActiveRecord::Migration[8.0]
  def change
    # Food/Bar Orders - Main order
    create_table :food_bar_orders, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.uuid :user_id, null: false
      t.uuid :booking_id
      t.string :order_number, null: false
      t.string :status, default: 'pending', null: false
      t.string :order_type, null: false # 'food', 'bar', 'both'
      t.decimal :subtotal, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :tax, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :tip_amount, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :tip_percentage, precision: 5, scale: 2
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0, null: false
      t.string :currency, default: 'USD', null: false
      t.text :special_instructions
      t.text :dietary_restrictions
      t.text :allergies
      t.boolean :is_split_bill, default: false, null: false
      t.integer :split_count, default: 1
      t.string :payment_status, default: 'pending', null: false
      t.uuid :payment_transaction_id
      t.datetime :ordered_at
      t.datetime :confirmed_at
      t.datetime :preparing_at
      t.datetime :ready_at
      t.datetime :delivered_at
      t.datetime :completed_at
      t.datetime :canceled_at
      t.timestamps
    end

    add_index :food_bar_orders, :event_id
    add_index :food_bar_orders, :user_id
    add_index :food_bar_orders, :booking_id
    add_index :food_bar_orders, :order_number, unique: true
    add_index :food_bar_orders, :status
    add_index :food_bar_orders, :order_type
    add_index :food_bar_orders, :payment_status
    add_index :food_bar_orders, :ordered_at
    
    add_foreign_key :food_bar_orders, :events, on_delete: :cascade
    add_foreign_key :food_bar_orders, :users, on_delete: :cascade
    add_foreign_key :food_bar_orders, :bookings, on_delete: :nullify
    add_foreign_key :food_bar_orders, :payment_transactions, on_delete: :nullify
    
    add_check_constraint :food_bar_orders,
      "status IN ('pending', 'confirmed', 'preparing', 'ready', 'delivered', 'completed', 'canceled')",
      name: 'check_food_bar_order_status'
    
    add_check_constraint :food_bar_orders,
      "order_type IN ('food', 'bar', 'both')",
      name: 'check_food_bar_order_type'
    
    add_check_constraint :food_bar_orders,
      "payment_status IN ('pending', 'paid', 'failed', 'refunded', 'split_pending')",
      name: 'check_food_bar_order_payment_status'
    
    add_check_constraint :food_bar_orders,
      "split_count >= 1",
      name: 'check_food_bar_order_split_count'

    # Order Items - Individual items in an order
    create_table :food_bar_order_items, id: :uuid do |t|
      t.uuid :food_bar_order_id, null: false
      t.uuid :menu_item_id, null: false
      t.integer :quantity, default: 1, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.text :customizations
      t.text :special_instructions
      t.timestamps
    end

    add_index :food_bar_order_items, :food_bar_order_id
    add_index :food_bar_order_items, :menu_item_id
    add_foreign_key :food_bar_order_items, :food_bar_orders, on_delete: :cascade
    add_foreign_key :food_bar_order_items, :menu_items, on_delete: :restrict
    
    add_check_constraint :food_bar_order_items,
      "quantity > 0",
      name: 'check_food_bar_order_item_quantity'
    
    add_check_constraint :food_bar_order_items,
      "unit_price >= 0",
      name: 'check_food_bar_order_item_unit_price'

    # Bill Splits - For splitting bills among multiple people
    create_table :bill_splits, id: :uuid do |t|
      t.uuid :food_bar_order_id, null: false
      t.uuid :user_id # null if splitting with non-registered person
      t.string :split_name # Name if not a registered user
      t.string :split_email
      t.string :split_phone
      t.decimal :split_amount, precision: 10, scale: 2, null: false
      t.string :payment_status, default: 'pending', null: false
      t.uuid :payment_transaction_id
      t.datetime :paid_at
      t.timestamps
    end

    add_index :bill_splits, :food_bar_order_id
    add_index :bill_splits, :user_id
    add_index :bill_splits, :payment_status
    add_foreign_key :bill_splits, :food_bar_orders, on_delete: :cascade
    add_foreign_key :bill_splits, :users, on_delete: :nullify
    add_foreign_key :bill_splits, :payment_transactions, on_delete: :nullify
    
    add_check_constraint :bill_splits,
      "payment_status IN ('pending', 'paid', 'failed', 'refunded')",
      name: 'check_bill_split_payment_status'
    
    add_check_constraint :bill_splits,
      "split_amount >= 0",
      name: 'check_bill_split_amount'
  end
end

