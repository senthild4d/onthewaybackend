class CreateVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :venues, id: :uuid do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.string :name, null: false
      t.text :description
      t.string :address1
      t.string :address2
      t.string :city, null: false
      t.string :region
      t.string :country, null: false
      t.string :postal_code
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.integer :capacity
      t.string :contact_email
      t.string :contact_phone, limit: 20
      t.string :status, default: 'active', null: false
      
      t.timestamps
    end
    
    add_index :venues, :city
    add_index :venues, :status
    add_index :venues, [:latitude, :longitude]
    add_check_constraint :venues, "status IN ('active', 'inactive')", name: 'check_venue_status'
    add_check_constraint :venues, "capacity IS NULL OR capacity > 0", name: 'check_venue_capacity'
  end
end
