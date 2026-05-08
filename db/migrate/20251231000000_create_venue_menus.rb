class CreateVenueMenus < ActiveRecord::Migration[8.0]
  def change
    # Venue Menu - Links venues to available food/bar menus
    create_table :venue_menus, id: :uuid do |t|
      t.uuid :venue_id, null: false
      t.string :name, null: false
      t.string :menu_type, null: false # 'food', 'bar', 'both'
      t.text :description
      t.boolean :is_active, default: true, null: false
      t.datetime :available_from
      t.datetime :available_until
      t.timestamps
    end

    add_index :venue_menus, :venue_id
    add_index :venue_menus, :menu_type
    add_index :venue_menus, :is_active
    add_foreign_key :venue_menus, :venues, on_delete: :cascade
    
    add_check_constraint :venue_menus,
      "menu_type IN ('food', 'bar', 'both')",
      name: 'check_venue_menu_type'

    # Venue Menu Categories - Organize menu items
    create_table :venue_menu_categories, id: :uuid do |t|
      t.uuid :venue_menu_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :category_type # 'food', 'bar', 'drinks', 'dessert', 'appetizer', 'main', 'other'
      t.integer :display_order, default: 0, null: false
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end

    add_index :venue_menu_categories, :venue_menu_id
    add_index :venue_menu_categories, [:venue_menu_id, :display_order]
    add_foreign_key :venue_menu_categories, :venue_menus, on_delete: :cascade

    # Venue Menu Items - Individual food/bar items
    create_table :venue_menu_items, id: :uuid do |t|
      t.uuid :venue_menu_category_id, null: false
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
      t.text :ingredients
      t.integer :preparation_time_minutes
      t.integer :display_order, default: 0, null: false
      t.timestamps
    end

    add_index :venue_menu_items, :venue_menu_category_id
    add_index :venue_menu_items, :is_available
    add_index :venue_menu_items, [:venue_menu_category_id, :display_order]
    add_foreign_key :venue_menu_items, :venue_menu_categories, on_delete: :cascade
    
    add_check_constraint :venue_menu_items,
      "price >= 0",
      name: 'check_venue_menu_item_price'
  end
end

