class CreateEventMenus < ActiveRecord::Migration[8.0]
  def change
    # Event Menu - Links events to available food/bar menus
    create_table :event_menus, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.string :name, null: false
      t.string :menu_type, null: false # 'food', 'bar', 'both'
      t.text :description
      t.boolean :is_active, default: true, null: false
      t.datetime :available_from
      t.datetime :available_until
      t.timestamps
    end

    add_index :event_menus, :event_id
    add_index :event_menus, :menu_type
    add_index :event_menus, :is_active
    add_foreign_key :event_menus, :events, on_delete: :cascade
    
    add_check_constraint :event_menus,
      "menu_type IN ('food', 'bar', 'both')",
      name: 'check_event_menu_type'

    # Menu Categories - Organize menu items
    create_table :menu_categories, id: :uuid do |t|
      t.uuid :event_menu_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :display_order, default: 0, null: false
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end

    add_index :menu_categories, :event_menu_id
    add_index :menu_categories, [:event_menu_id, :display_order]
    add_foreign_key :menu_categories, :event_menus, on_delete: :cascade

    # Menu Items - Individual food/bar items
    create_table :menu_items, id: :uuid do |t|
      t.uuid :menu_category_id, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.string :item_type # 'food', 'drink', 'appetizer', 'main', 'dessert', 'cocktail', 'beer', 'wine', 'non_alcoholic'
      t.string :image_url
      t.boolean :is_available, default: true, null: false
      t.boolean :is_vegetarian, default: false
      t.boolean :is_vegan, default: false
      t.boolean :is_gluten_free, default: false
      t.boolean :contains_alcohol, default: false
      t.text :allergens, array: true, default: []
      t.text :dietary_info
      t.integer :preparation_time_minutes
      t.integer :display_order, default: 0, null: false
      t.timestamps
    end

    add_index :menu_items, :menu_category_id
    add_index :menu_items, :is_available
    add_index :menu_items, [:menu_category_id, :display_order]
    add_foreign_key :menu_items, :menu_categories, on_delete: :cascade
    
    add_check_constraint :menu_items,
      "price >= 0",
      name: 'check_menu_item_price'
  end
end

