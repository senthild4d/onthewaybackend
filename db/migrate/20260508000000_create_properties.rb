class CreateProperties < ActiveRecord::Migration[8.0]
  def change
    create_table :properties, id: :uuid do |t|
      t.uuid :owner_id, null: false

      t.string :title, null: false
      t.text :description

      t.string :property_type
      t.integer :bedrooms
      t.integer :bathrooms
      t.decimal :area_sqft, precision: 12, scale: 2

      t.string :address1
      t.string :address2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country

      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7

      t.decimal :price, precision: 12, scale: 2
      t.string :currency, default: 'USD', null: false

      t.string :approval_status, default: 'draft', null: false
      t.datetime :submitted_at
      t.uuid :approved_by_id
      t.datetime :approved_at
      t.uuid :rejected_by_id
      t.datetime :rejected_at
      t.text :rejection_reason

      t.timestamps
    end

    add_index :properties, :owner_id
    add_index :properties, :approval_status
    add_index :properties, [:latitude, :longitude]

    add_foreign_key :properties, :users, column: :owner_id
    add_foreign_key :properties, :users, column: :approved_by_id, on_delete: :nullify
    add_foreign_key :properties, :users, column: :rejected_by_id, on_delete: :nullify

    add_check_constraint :properties,
                         "approval_status IN ('draft','pending_review','approved','rejected','archived')",
                         name: 'check_properties_approval_status'
    add_check_constraint :properties,
                         "latitude IS NULL OR (latitude >= -90 AND latitude <= 90)",
                         name: 'check_properties_latitude'
    add_check_constraint :properties,
                         "longitude IS NULL OR (longitude >= -180 AND longitude <= 180)",
                         name: 'check_properties_longitude'
    add_check_constraint :properties,
                         "price IS NULL OR price >= 0",
                         name: 'check_properties_price_non_negative'
  end
end

