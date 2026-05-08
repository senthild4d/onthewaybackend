class ExtendPropertiesForFiltersAndLifecycle < ActiveRecord::Migration[8.0]
  def change
    change_table :properties, bulk: true do |t|
      # Sale/Rent
      t.string :purpose, default: 'sale', null: false

      # Lifecycle (separate from approval)
      t.string :listing_status, default: 'active', null: false # active | sold | archived
      t.datetime :sold_at
      t.uuid :sold_by_id
      t.datetime :archived_at
      t.uuid :archived_by_id

      # Area: prefer sqm for EU markets
      t.decimal :area_sqm, precision: 12, scale: 2

      # Filtering helpers
      t.integer :year_built
      t.integer :floor
      t.integer :total_floors
      t.boolean :furnished
      t.integer :parking_spaces

      # Flexible feature flags: { "elevator": true, "balcony": true, ... }
      t.jsonb :features, default: {}, null: false
    end

    add_index :properties, :purpose
    add_index :properties, :listing_status
    add_index :properties, :archived_at
    add_index :properties, :sold_at
    add_index :properties, :sold_by_id
    add_index :properties, :archived_by_id
    add_index :properties, :area_sqm
    add_index :properties, :bedrooms
    add_index :properties, :bathrooms
    add_index :properties, :property_type
    add_index :properties, :price

    add_foreign_key :properties, :users, column: :sold_by_id, on_delete: :nullify
    add_foreign_key :properties, :users, column: :archived_by_id, on_delete: :nullify

    add_check_constraint :properties,
                         "purpose IN ('sale','rent')",
                         name: 'check_properties_purpose'
    add_check_constraint :properties,
                         "listing_status IN ('active','sold','archived')",
                         name: 'check_properties_listing_status'
    add_check_constraint :properties,
                         "area_sqm IS NULL OR area_sqm >= 0",
                         name: 'check_properties_area_sqm_non_negative'
    add_check_constraint :properties,
                         "year_built IS NULL OR (year_built >= 1600 AND year_built <= EXTRACT(YEAR FROM NOW())::int + 1)",
                         name: 'check_properties_year_built'
    add_check_constraint :properties,
                         "floor IS NULL OR floor >= -5",
                         name: 'check_properties_floor_min'
    add_check_constraint :properties,
                         "parking_spaces IS NULL OR parking_spaces >= 0",
                         name: 'check_properties_parking_non_negative'
  end
end

